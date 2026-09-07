import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../scoring/asr_segment.dart';
import '../scoring/score_item.dart';
import '../scoring/subtest_outcome.dart';
import 'app_language.dart';
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
import 'digit_sequence_player.dart';
import 'event_trace.dart';
import 'live_session.dart';
import 'similarity_client.dart';
import 'subtest_spec.dart';

enum SessionPhase { instruction, stimulus, recording, tapping, scoring, error, done }

/// Drives one subtest: instruction → stimulus → response → score.
class SubtestSessionController extends ChangeNotifier {
  final SubtestSpec spec;
  final AsrClient asr;
  final VoiceRecorder recorder;
  final AudioPlayback playback;
  final DateTime? referenceDate;

  /// Only abstraction consults it. Constructed by default rather than required
  /// so the eight other subtests need no extra wiring at their call sites.
  final SimilarityClient similarity;

  /// Where raw timestamped events are appended. Null when no session is in
  /// progress — under `flutter test`, and on any page reached without going
  /// through [LiveSession.start] — so every write below is null-guarded.
  /// Tracing must never be the reason a subtest cannot be administered.
  final TraceLog? trace;

  late final DigitSequencePlayer _digitPlayer;

  /// Injectable because asset resolution under `flutter test` is not
  /// dependable, and a false negative would make a subtest skip silently.
  final Future<bool> Function(String) _assetExists;

  SessionPhase _phase = SessionPhase.instruction;
  String? _error;
  SubtestOutcome? _outcome;

  /// Retires an in-flight attempt. Without it, a second begin() leaves the
  /// previous attempt's continuation running and two stimulus streams play
  /// over each other. Also bumped by skip(), retry(), and dispose() so any
  /// attempt still in flight (including a suspended finishRecording()) is
  /// retired and cannot write a stale result afterward.
  int _generation = 0;

  /// Set by dispose(). Guards _setPhase against notifying listeners on a
  /// disposed ChangeNotifier if a retired attempt somehow reaches it.
  bool _disposed = false;

  final List<int> _taps = [];
  DateTime? _sequenceStartedAt;

  SubtestSessionController({
    required this.spec,
    required this.asr,
    required this.recorder,
    required this.playback,
    SimilarityClient? similarity,
    DigitSequencePlayer? digitPlayer,
    TraceLog? trace,
    this.referenceDate,
    Future<bool> Function(String)? assetExists,
  })  : similarity = similarity ?? HttpSimilarityClient(),
        trace = trace ?? LiveSession.current?.trace,
        _assetExists = assetExists ?? _bundleHasAsset {
    _digitPlayer = digitPlayer ??
        DigitSequencePlayer(playback: playback, language: AppLanguage.current);
  }

  static Future<bool> _bundleHasAsset(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  SessionPhase get phase => _phase;
  String? get error => _error;
  SubtestOutcome? get outcome => _outcome;

  void _setPhase(SessionPhase next) {
    if (_disposed) return;
    _phase = next;
    notifyListeners();
  }

  /// Fire and forget: called from synchronous UI handlers (skip, retry), and
  /// a recorder that was never started must not throw out of one.
  void _closeMicrophone() {
    unawaited(recorder.stop().catchError((_) => const <int>[]));
  }

  /// Appends one event, if a session is in progress. Every call site goes
  /// through this rather than `trace?.add(...)` so that adding tracing cannot
  /// change control flow: it takes no arguments a caller has to compute and
  /// returns nothing anyone branches on.
  void _mark(String type, {Map<String, dynamic> data = const {}}) {
    trace?.add(spec.id, type, data: data);
  }

  Future<void> begin() async {
    _generation += 1;
    final generation = _generation;
    bool abandoned() => _generation != generation;

    _error = null;
    _mark(TraceEventType.started);

    try {
      if (spec.responseMode == ResponseMode.tap) {
        await _runTapSequence(abandoned);
        return;
      }

      final stimulus = spec.stimulusAssetForLanguage;
      if (stimulus != null) {
        // A voice subtest that declares a stimulus but has no file is not
        // administrable — recording the patient answering a question they
        // never heard would produce a score for nothing. Sentence repetition
        // ships in exactly this state. A null stimulus is different: it means
        // the subtest has no stimulus by design, and the microphone opens
        // immediately.
        final exists = await _assetExists(stimulus);
        // Checked before acting on the result: a retired attempt must not
        // write a skip outcome either, only a live one may complete.
        if (abandoned()) return;
        if (!exists) {
          _complete(SubtestOutcome.skippedFor(spec.id));
          return;
        }

        _setPhase(SessionPhase.stimulus);
        _mark(TraceEventType.stimulusStart);
        await playback.play(stimulus);
        if (abandoned()) return;
        // The origin for every initiation-latency measurement on a voice
        // subtest: time from the stimulus ending to the patient speaking.
        _mark(TraceEventType.stimulusEnd);
      }

      // The microphone opens only here, strictly after playback has finished.
      await recorder.start();
      if (abandoned()) {
        // The microphone opened for a subtest nobody is on any more. Close it
        // rather than leaving the stream live and the recorder unreachable.
        await recorder.stop();
        return;
      }
      _setPhase(SessionPhase.recording);
      _mark(TraceEventType.recordingStart);
    } catch (e) {
      if (abandoned()) return;
      _error = e.toString();
      // Recorded so a 0 that came from an outage is distinguishable afterwards
      // from a 0 the patient earned.
      _mark(TraceEventType.failed, data: {'where': 'begin', 'error': '$e'});
      _setPhase(SessionPhase.error);
    }
  }

  Future<void> _runTapSequence(bool Function() abandoned) async {
    _taps.clear();

    // Mirror the voice path. A subtest whose stimulus cannot sound was never
    // administered — without this, total audio failure records a real 0/1,
    // asserting the patient failed a task they never heard.
    if (!await _assetExists(vigilanceAssetFor(language: AppLanguage.current))) {
      _complete(SubtestOutcome.skippedFor(spec.id));
      return;
    }
    if (abandoned()) return;

    await _digitPlayer.play(
      spec.sequence!,
      intervalMs: spec.intervalMs,
      leadInMs: spec.leadInMs,
      onStart: () {
        if (abandoned()) return;
        // The origin every tap offset is measured from. Set at the first
        // digit's onset, not at begin(), because the lead-in sits in between.
        _sequenceStartedAt = DateTime.now();
        _setPhase(SessionPhase.tapping);
        _mark(TraceEventType.stimulusStart);
        _markDigitOnsets();
      },
    );
    if (abandoned()) return;
    _mark(TraceEventType.stimulusEnd);

    _setPhase(SessionPhase.scoring);
    // Vigilance never reaches the network (scoreVigilance is pure), so this
    // await completes on the next microtask. The abandoned() re-check after it
    // is kept anyway: the guard belongs to the await, not to the scorer, and
    // dropping it would rot the moment any tap subtest gains a backend rule.
    final outcome =
        await scoreItem(spec, taps: List.of(_taps), referenceDate: referenceDate);
    if (abandoned()) return;
    _complete(outcome);
  }

  Future<void> finishRecording() async {
    // A double-tap on submit (or any second call) must not re-run scoring: the
    // recording is already gone by then, so it would silently score an empty
    // transcript over a real one.
    if (_phase != SessionPhase.recording) return;

    // Captured so a later skip()/retry()/begin()/dispose() can retire this
    // attempt while it is suspended waiting on the network. finishRecording is
    // the only path that writes a real score, so it is the one place this
    // guard matters most.
    final generation = _generation;
    bool abandoned() => _generation != generation;

    // Marked before the phase change so the offset is the moment the patient
    // pressed submit, not the moment the microphone finished closing.
    _mark(TraceEventType.recordingEnd);
    _setPhase(SessionPhase.scoring);
    _mark(TraceEventType.scoringStart);
    try {
      final bytes = await recorder.stop();
      final AsrResult result = await asr.transcribe(
        bytes,
        language: AppLanguage.isEnglish ? 'en' : 'th',
      );
      final List<AsrSegment> segments = result.segments;

      if (abandoned()) return;
      // Abstraction makes this second await a real network call, so the
      // abandoned() check is repeated AFTER it. Without that, a skip() during
      // the similarity request would be overwritten by the score that came
      // back afterwards — the same stale-write bug the transcription await
      // above is already guarded against.
      final outcome = await scoreItem(
        spec,
        transcript: result.text,
        segments: segments,
        referenceDate: referenceDate,
        similarity: similarity,
      );
      if (abandoned()) return;
      _complete(outcome);
    } catch (e) {
      if (abandoned()) return;
      _error = e.toString();
      // Which subtests failed, and why, is exactly what tells a reviewer that
      // a low total reflects a backend outage rather than the patient.
      _mark(TraceEventType.failed,
          data: {'where': 'finishRecording', 'error': '$e'});
      _setPhase(SessionPhase.error);
    }
  }

  /// Writes down when each digit sounds, at the moment the sequence starts.
  ///
  /// Computed from the sequence and interval rather than observed per digit,
  /// because `DigitSequencePlayer` reports only the start of the whole run.
  /// That makes these *scheduled* onsets, not measured ones — good enough for
  /// error position across the 29 digits (the vigilance-decrement measure),
  /// and honest about being derived from the schedule: `scheduled: true` says
  /// so in the stored data rather than letting a later reader assume otherwise.
  void _markDigitOnsets() {
    final sequence = spec.sequence;
    final target = spec.target;
    if (sequence == null || target == null) return;
    for (var i = 0; i < sequence.length; i++) {
      trace?.add(
        spec.id,
        TraceEventType.digitPlayed,
        data: {
          'index': i,
          'digit': sequence[i],
          'isTarget': sequence[i] == target,
          'offsetMs': i * spec.intervalMs,
          'scheduled': true,
        },
      );
    }
  }

  /// A no-op outside the tapping phase: a press during the lead-in or after
  /// the last window is not an answer to any digit, so it must not become one.
  void recordTap() {
    if (_phase != SessionPhase.tapping) return;
    final started = _sequenceStartedAt;
    if (started == null) return;
    final offsetMs = DateTime.now().difference(started).inMilliseconds;
    _taps.add(offsetMs);
    // Every tap, including ones the scorer collapses into a single window
    // event. Misses vs. false taps, latency variance and vigilance decrement
    // are all recomputed from these later — none of them are derived here.
    _mark(TraceEventType.tap, data: {'sinceSequenceStartMs': offsetMs});
  }

  void retry() {
    _generation += 1;
    // A subtest retried three times is not the same as one answered first
    // time, even at the same score. Recorded before the state is reset so the
    // attempt that is being abandoned is still identifiable in the trace.
    _mark(TraceEventType.retried);
    _digitPlayer.stop();
    // The mic may still be open (phase was recording) or already mid-close
    // (phase was scoring, awaiting transcription). Either way retry() must
    // not leave it live into the next attempt, and calling stop() again on an
    // already-stopped fake/real recorder is harmless.
    _closeMicrophone();
    _error = null;
    _setPhase(SessionPhase.instruction);
  }

  /// A skipped subtest was never administered, so it scores nothing rather
  /// than scoring 0 — 0 would assert the patient failed.
  SubtestOutcome skip() {
    _generation += 1;
    _digitPlayer.stop();
    _closeMicrophone();
    _error = null;
    final outcome = SubtestOutcome.skippedFor(spec.id);
    _complete(outcome);
    return outcome;
  }

  void _complete(SubtestOutcome outcome) {
    _outcome = outcome;
    // The single place a subtest's result reaches the trace, so the two ways a
    // subtest can end up skipped — the clinician pressing skip, and a declared
    // stimulus failing to load — record identically. The score lands here as
    // well as in the outcome, so a trace is self-contained for review even
    // read on its own.
    _mark(
      outcome.skipped ? TraceEventType.skipped : TraceEventType.scored,
      data: {
        'score': outcome.score,
        'maxScore': outcome.maxScore,
        'skipped': outcome.skipped,
      },
    );
    _setPhase(SessionPhase.done);
  }

  @override
  void dispose() {
    // First, so any attempt suspended mid-await (playback, recorder.start,
    // transcription) resumes into an abandoned() check that returns before
    // touching a disposed recorder/playback or calling notifyListeners().
    _generation += 1;
    _disposed = true;
    _digitPlayer.stop();
    recorder.dispose();
    playback.dispose();
    super.dispose();
  }
}

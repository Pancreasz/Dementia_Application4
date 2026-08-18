import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../scoring/asr_segment.dart';
import '../scoring/score_item.dart';
import '../scoring/subtest_outcome.dart';
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
import 'digit_sequence_player.dart';
import 'subtest_spec.dart';

enum SessionPhase { instruction, stimulus, recording, tapping, scoring, error, done }

/// Drives one subtest: instruction → stimulus → response → score.
class SubtestSessionController extends ChangeNotifier {
  final SubtestSpec spec;
  final AsrClient asr;
  final VoiceRecorder recorder;
  final AudioPlayback playback;
  final DateTime? referenceDate;
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
    DigitSequencePlayer? digitPlayer,
    this.referenceDate,
    Future<bool> Function(String)? assetExists,
  }) : _assetExists = assetExists ?? _bundleHasAsset {
    _digitPlayer = digitPlayer ?? DigitSequencePlayer(playback: playback);
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

  Future<void> begin() async {
    _generation += 1;
    final generation = _generation;
    bool abandoned() => _generation != generation;

    _error = null;

    try {
      if (spec.responseMode == ResponseMode.tap) {
        await _runTapSequence(abandoned);
        return;
      }

      final stimulus = spec.stimulusAsset;
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
        await playback.play(stimulus);
        if (abandoned()) return;
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
    } catch (e) {
      if (abandoned()) return;
      _error = e.toString();
      _setPhase(SessionPhase.error);
    }
  }

  Future<void> _runTapSequence(bool Function() abandoned) async {
    _taps.clear();

    // Mirror the voice path. A subtest whose stimulus cannot sound was never
    // administered — without this, total audio failure records a real 0/1,
    // asserting the patient failed a task they never heard.
    for (final digit in spec.sequence!.split('').toSet()) {
      if (!await _assetExists('assets/moca/audio/digit-$digit.wav')) {
        _complete(SubtestOutcome.skippedFor(spec.id));
        return;
      }
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
      },
    );
    if (abandoned()) return;

    _setPhase(SessionPhase.scoring);
    _complete(scoreItem(spec, taps: List.of(_taps), referenceDate: referenceDate));
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

    _setPhase(SessionPhase.scoring);
    try {
      final bytes = await recorder.stop();
      final AsrResult result = await asr.transcribe(bytes);
      final List<AsrSegment> segments = result.segments;

      if (abandoned()) return;
      _complete(scoreItem(
        spec,
        transcript: result.text,
        segments: segments,
        referenceDate: referenceDate,
      ));
    } catch (e) {
      if (abandoned()) return;
      _error = e.toString();
      _setPhase(SessionPhase.error);
    }
  }

  /// A no-op outside the tapping phase: a press during the lead-in or after
  /// the last window is not an answer to any digit, so it must not become one.
  void recordTap() {
    if (_phase != SessionPhase.tapping) return;
    final started = _sequenceStartedAt;
    if (started == null) return;
    _taps.add(DateTime.now().difference(started).inMilliseconds);
  }

  void retry() {
    _generation += 1;
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

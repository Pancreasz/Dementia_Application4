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
  /// over each other.
  int _generation = 0;

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
    _phase = next;
    notifyListeners();
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
        if (!await _assetExists(stimulus)) {
          _complete(SubtestOutcome.skippedFor(spec.id));
          return;
        }
        if (abandoned()) return;

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
    _setPhase(SessionPhase.scoring);
    try {
      final bytes = await recorder.stop();
      final AsrResult result = await asr.transcribe(bytes);
      final List<AsrSegment> segments = result.segments;

      _complete(scoreItem(
        spec,
        transcript: result.text,
        segments: segments,
        referenceDate: referenceDate,
      ));
    } catch (e) {
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
    _error = null;
    _setPhase(SessionPhase.instruction);
  }

  /// A skipped subtest was never administered, so it scores nothing rather
  /// than scoring 0 — 0 would assert the patient failed.
  SubtestOutcome skip() {
    _generation += 1;
    _digitPlayer.stop();
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
    _digitPlayer.stop();
    recorder.dispose();
    playback.dispose();
    super.dispose();
  }
}

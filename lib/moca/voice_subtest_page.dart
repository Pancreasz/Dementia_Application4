import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/score.dart' as globals;
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
import 'score_log.dart';
import 'session_controller.dart';
import 'subtest_spec.dart';

/// Renders any of the nine subtests from its spec. There is deliberately one
/// of these rather than nine pages: the record → transcribe → score → advance
/// pipeline exists once.
class VoiceSubtestPage extends StatefulWidget {
  final SubtestSpec spec;
  final String nextRoute;

  /// Injected by tests. Production builds a controller wired to the real
  /// microphone, speakers and endpoint.
  final SubtestSessionController Function(SubtestSpec)? controllerFactory;

  const VoiceSubtestPage({
    super.key,
    required this.spec,
    required this.nextRoute,
    this.controllerFactory,
  });

  @override
  State<VoiceSubtestPage> createState() => _VoiceSubtestPageState();
}

class _VoiceSubtestPageState extends State<VoiceSubtestPage> {
  late final SubtestSessionController _controller;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    _controller = (widget.controllerFactory ?? _defaultController)(widget.spec);
    _controller.addListener(_onPhaseChanged);
  }

  SubtestSessionController _defaultController(SubtestSpec spec) =>
      SubtestSessionController(
        spec: spec,
        asr: HttpAsrClient(endpoint: Uri.parse(kDefaultAsrEndpoint)),
        recorder: DeviceVoiceRecorder(),
        playback: DeviceAudioPlayback(),
      );

  void _onPhaseChanged() {
    if (!mounted) return;

    if (_controller.phase == SessionPhase.recording &&
        widget.spec.enforceTimeLimit) {
      // Verbal fluency alone. Its 60 seconds is what the "11 or more words"
      // cutoff is normed against, so it is a real deadline rather than the
      // budget every other subtest carries.
      _deadline?.cancel();
      _deadline = Timer(
        Duration(seconds: widget.spec.timeLimitSec!),
        () {
          if (mounted && _controller.phase == SessionPhase.recording) {
            _controller.finishRecording();
          }
        },
      );
    }

    if (_controller.phase == SessionPhase.done) {
      _deadline?.cancel();
      final outcome = _controller.outcome!;
      // Every completed subtest reaches done exactly once, skips included, so
      // this is the single choke point for logging a voice result.
      logSubtestOutcome(outcome);
      globals.voiceOutcomes[widget.spec.id] = outcome;
      Navigator.pushReplacementNamed(context, widget.nextRoute);
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _controller.removeListener(_onPhaseChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A patient cannot back out of a voice subtest mid-administration — that
    // would otherwise leave a recording in flight and no outcome written.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.spec.section),
          backgroundColor: const Color.fromARGB(255, 87, 152, 225),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.spec.instructionTh,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ..._bodyForPhase(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _bodyForPhase() {
    switch (_controller.phase) {
      case SessionPhase.instruction:
        return [_button('เริ่ม', _controller.begin)];

      case SessionPhase.stimulus:
        return [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('กำลังเล่นเสียง กรุณาฟัง'),
          const SizedBox(height: 24),
          // Stimulus playback can hang on a device with no working audio
          // output, and PopScope(canPop: false) blocks the back gesture, so
          // without this the only way out is a force-quit — which loses every
          // score in the session, nothing being persisted.
          _skipButton(),
        ];

      case SessionPhase.recording:
        return [
          const Icon(Icons.mic, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('กำลังบันทึกเสียง'),
          const SizedBox(height: 24),
          _button('ส่งคำตอบ', _controller.finishRecording),
        ];

      case SessionPhase.tapping:
        return [
          _button('เคาะ', () async => _controller.recordTap()),
        ];

      case SessionPhase.scoring:
        return [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('กำลังตรวจคำตอบ'),
          const SizedBox(height: 8),
          // The ASR timeout is 180 s. Saying so is the difference between a
          // slow screen and an apparently frozen one.
          const Text(
            'อาจใช้เวลาสูงสุดประมาณ 3 นาที',
            style: TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Transcription can sit here for the full timeout. skip() bumps the
          // generation counter, so the in-flight attempt is retired and cannot
          // overwrite the skipped outcome when it eventually returns.
          _skipButton(),
        ];

      case SessionPhase.error:
        return [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text('เกิดข้อผิดพลาด: ${_controller.error ?? ''}',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _button('ลองใหม่', () async => _controller.retry()),
          const SizedBox(height: 12),
          // Skip records that the subtest was never administered, which is not
          // the same as the patient scoring 0.
          _button('ข้าม', () async => _controller.skip()),
        ];

      case SessionPhase.done:
        return [const CircularProgressIndicator()];
    }
  }

  /// Deliberately quieter than [_button]: on the two spinner phases this is
  /// the only control on screen, sitting where a patient may idly press, and a
  /// stray press abandons the subtest. It records "never administered", which
  /// is not a score of 0 — see SubtestOutcome.skippedFor.
  Widget _skipButton() => TextButton(
        onPressed: () => _controller.skip(),
        child: const Text(
          'ข้ามข้อนี้',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );

  Widget _button(String label, Future<void> Function() onPressed) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => onPressed(),
        child: Text(label),
      );
}

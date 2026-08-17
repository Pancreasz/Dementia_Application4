import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/score.dart' as globals;
import 'asr_client.dart';
import 'audio_player.dart';
import 'audio_recorder.dart';
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
      globals.voiceOutcomes[widget.spec.id] = _controller.outcome!;
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
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.spec.instructionTh,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ..._bodyForPhase(),
            ],
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

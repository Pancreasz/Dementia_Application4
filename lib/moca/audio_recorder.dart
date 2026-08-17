import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The microphone, behind an interface so the session controller can be tested
/// without one.
abstract class VoiceRecorder {
  Future<void> start();

  /// Returns the recorded audio as bytes, ready to POST to /transcribe.
  Future<List<int>> stop();

  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was refused');
    }

    final dir = await getTemporaryDirectory();
    _path =
        '${dir.path}/moca-${DateTime.now().millisecondsSinceEpoch}.wav';

    // 16 kHz mono PCM: what the endpoint expects, and what the model wants.
    // Recording at a higher rate only to downsample server-side wastes upload
    // time on a connection the patient is waiting on.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );
  }

  @override
  Future<List<int>> stop() async {
    await _recorder.stop();
    final path = _path;
    if (path == null) return const [];
    final file = File(path);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();
    // The upload is the only consumer; leaving these behind fills the temp
    // directory over a long session.
    try {
      await file.delete();
    } catch (_) {}
    return bytes;
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

class FakeVoiceRecorder implements VoiceRecorder {
  final List<String> calls = [];
  final List<int> bytes;
  final Object? throwsOnStart;

  FakeVoiceRecorder({this.bytes = const [1], this.throwsOnStart});

  @override
  Future<void> start() async {
    calls.add('start');
    if (throwsOnStart != null) throw throwsOnStart!;
  }

  @override
  Future<List<int>> stop() async {
    calls.add('stop');
    return bytes;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}

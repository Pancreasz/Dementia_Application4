import 'package:record/record.dart';

import 'recording_sink.dart';

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

  /// Whether the take lands in a file or a Blob is the sink's business, not
  /// this class's — see recording_sink.dart.
  final PlatformRecordingSink _sink = PlatformRecordingSink();

  @override
  Future<void> start() async {
    // On the web this is what triggers the browser's microphone prompt, and it
    // only resolves at all in a secure context (https, or localhost during
    // development). A page served over plain http silently has no microphone.
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was refused');
    }

    // 16 kHz mono PCM: what the endpoint expects, and what the model wants.
    // Recording at a higher rate only to downsample server-side wastes upload
    // time on a connection the patient is waiting on.
    //
    // record_web implements the wav encoder through an AudioWorklet, so this
    // config is honoured in the browser too rather than falling back to the
    // MediaRecorder default of webm/opus.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: await _sink.newTarget(),
    );
  }

  @override
  Future<List<int>> stop() async {
    // stop()'s own return value is the handle — a file path on desktop, a
    // blob: URL in the browser. Discarding it and reconstructing the path (as
    // this did before) has no browser equivalent.
    final handle = await _recorder.stop();
    return _sink.readAndRelease(handle);
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

import 'package:audioplayers/audioplayers.dart';

/// Stimulus playback, behind an interface for the same reason as the recorder.
abstract class AudioPlayback {
  /// Resolves when the file has finished playing — not when it starts. The
  /// session controller relies on this: the microphone must not open until
  /// playback is genuinely over.
  Future<void> play(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceAudioPlayback implements AudioPlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String assetPath) async {
    // audioplayers' AssetSource is rooted at `assets/`, so strip the prefix
    // that pubspec.yaml and the rest of this codebase use.
    final source = assetPath.startsWith('assets/')
        ? assetPath.substring('assets/'.length)
        : assetPath;

    await _player.stop();

    // Subscribe BEFORE starting playback. onPlayerComplete is a broadcast
    // stream, so a file that finishes before the subscription attaches would
    // leave this future pending forever — and the digit files are only about
    // a second long, which is well inside that window.
    //
    // This is load-bearing rather than defensive: the session controller
    // implements "the microphone never opens before playback finishes" by
    // awaiting this future. Its unit tests use FakeAudioPlayback, so no test
    // in the suite can catch a hang here.
    final completed = _player.onPlayerComplete.first;
    await _player.play(AssetSource(source));
    await completed;
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

class FakeAudioPlayback implements AudioPlayback {
  final List<String> calls = [];

  @override
  Future<void> play(String assetPath) async {
    calls.add('play:$assetPath');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }
}

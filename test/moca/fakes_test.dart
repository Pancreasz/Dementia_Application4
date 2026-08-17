import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';

void main() {
  test('the fake recorder records the calls made to it', () async {
    final recorder = FakeVoiceRecorder(bytes: [1, 2, 3]);

    await recorder.start();
    final bytes = await recorder.stop();

    expect(recorder.calls, ['start', 'stop']);
    expect(bytes, [1, 2, 3]);
  });

  test('the fake playback records which assets it was asked to play', () async {
    final playback = FakeAudioPlayback();

    await playback.play('assets/moca/audio/digits-forward.wav');
    await playback.stop();

    expect(playback.calls,
        ['play:assets/moca/audio/digits-forward.wav', 'stop']);
  });
}

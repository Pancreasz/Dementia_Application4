import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/digit_sequence_player.dart';

void main() {
  testWidgets('plays each digit once, in order', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    final done = player.play('513', intervalMs: 1000, leadInMs: 1000);
    await tester.pump(const Duration(milliseconds: 4100));
    await done;

    expect(playback.calls, [
      'play:assets/moca/audio/digit-5.wav',
      'play:assets/moca/audio/digit-1.wav',
      'play:assets/moca/audio/digit-3.wav',
    ]);
  });

  // The origin every tap offset is measured from. It fires at the FIRST
  // DIGIT'S onset, not when play() was called — the lead-in silence sits in
  // between, and a tap during it is not an answer to any digit.
  testWidgets('fires onStart at the first digit, after the lead-in',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var started = false;

    final done =
        player.play('51', intervalMs: 1000, leadInMs: 1000, onStart: () => started = true);

    await tester.pump(const Duration(milliseconds: 500));
    expect(started, isFalse, reason: 'still inside the lead-in');

    await tester.pump(const Duration(milliseconds: 600));
    expect(started, isTrue);

    await tester.pump(const Duration(milliseconds: 2000));
    await done;
  });

  testWidgets('resolves when the last window closes, not when the last sound stops',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var resolved = false;

    player.play('51', intervalMs: 1000, leadInMs: 0).then((_) => resolved = true);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(resolved, isFalse);

    await tester.pump(const Duration(milliseconds: 200));
    expect(resolved, isTrue);
  });

  // A stopped sequence was abandoned, not completed. Resolving would let the
  // caller score a subtest that never finished.
  testWidgets('stop cancels the remaining digits', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('51319', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 1500));
    player.stop();
    await tester.pump(const Duration(milliseconds: 5000));

    expect(playback.calls.where((c) => c.startsWith('play:')).length, 2);
  });

  testWidgets('a second play retires the first', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('99999', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 1500));

    final second = player.play('51', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 2100));
    await second;

    final played = playback.calls.where((c) => c.startsWith('play:')).toList();
    expect(played.last, 'assets/moca/audio/digit-1.wav');
    expect(played.where((c) => c.contains('digit-9')).length, 2,
        reason: 'only the two digits that had already sounded');
  });
}

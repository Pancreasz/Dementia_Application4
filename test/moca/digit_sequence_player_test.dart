import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/digit_sequence_player.dart';

void main() {
  test('the merged stimulus follows the language', () {
    expect(vigilanceAssetFor(), 'assets/moca/audio/vigilance.wav');
    expect(vigilanceAssetFor(language: Language.en),
        'assets/moca/audio/eng-vigilance.wav');
  });

  // The whole point of the merge: one fetch, not one per digit. Streaming a
  // file per digit meant every digit depended on its own fetch and decode
  // beating the 1000 ms interval, which mobile browsers routinely lost.
  testWidgets('plays the sequence from a single merged file', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('513', intervalMs: 1000, leadInMs: 1000);
    await tester.pump(const Duration(milliseconds: 1100));

    expect(playback.calls, contains('load:assets/moca/audio/vigilance.wav'));
    expect(playback.calls.where((c) => c.startsWith('load:')).length, 1);
    expect(playback.calls.where((c) => c.startsWith('play:')), isEmpty,
        reason: 'no per-digit playback remains');

    player.stop();
  });

  testWidgets('uses the English stimulus in English mode', (tester) async {
    final playback = FakeAudioPlayback();
    final player =
        DigitSequencePlayer(playback: playback, language: Language.en);

    player.play('513', intervalMs: 1000, leadInMs: 1000);
    await tester.pump(const Duration(milliseconds: 1100));

    expect(playback.calls, contains('load:assets/moca/audio/eng-vigilance.wav'));

    player.stop();
  });

  // Loading during the lead-in is what keeps the tap clock honest: the fetch
  // and decode finish before the moment taps are measured from, instead of
  // sitting between that moment and the first audible digit.
  testWidgets('loads during the lead-in, starts after it', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('51', intervalMs: 1000, leadInMs: 1000);

    await tester.pump(const Duration(milliseconds: 500));
    expect(playback.calls, contains('load:assets/moca/audio/vigilance.wav'));
    expect(playback.calls, isNot(contains('start')),
        reason: 'still inside the lead-in');

    await tester.pump(const Duration(milliseconds: 600));
    expect(playback.calls, contains('start'));

    player.stop();
  });

  // The origin every tap offset is measured from. It fires when the sound
  // actually starts, not when play() was called — the lead-in sits in between,
  // and a tap during it is not an answer to any digit.
  testWidgets('fires onStart at the first digit, after the lead-in',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var started = false;

    player.play('51',
        intervalMs: 1000, leadInMs: 1000, onStart: () => started = true);

    await tester.pump(const Duration(milliseconds: 500));
    expect(started, isFalse, reason: 'still inside the lead-in');

    await tester.pump(const Duration(milliseconds: 600));
    expect(started, isTrue);

    player.stop();
  });

  testWidgets('onStart fires only after playback has begun', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    List<String>? callsAtStart;

    player.play('51',
        intervalMs: 1000,
        leadInMs: 0,
        onStart: () => callsAtStart = List.of(playback.calls));
    await tester.pump(const Duration(milliseconds: 100));

    expect(callsAtStart, isNotNull);
    expect(callsAtStart, contains('start'));

    player.stop();
  });

  testWidgets(
      'resolves when the last window closes, not when the last sound stops',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var resolved = false;

    player.play('51', intervalMs: 1000, leadInMs: 0).then((_) => resolved = true);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(resolved, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    expect(resolved, isTrue);
  });

  // Windows are timed from the sound starting, so a late start moves the
  // digits and their windows together rather than pulling them apart.
  testWidgets('the windows run from the first digit, not from play()',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var resolved = false;

    player
        .play('51', intervalMs: 1000, leadInMs: 1000)
        .then((_) => resolved = true);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(resolved, isFalse, reason: 'lead-in does not count toward a window');

    await tester.pump(const Duration(milliseconds: 700));
    expect(resolved, isTrue);
  });

  // A stopped sequence was abandoned, not completed. Resolving would let the
  // caller score a subtest that never finished.
  testWidgets('stop halts playback and leaves the future unsettled',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var resolved = false;

    player
        .play('51319', intervalMs: 1000, leadInMs: 0)
        .then((_) => resolved = true);
    await tester.pump(const Duration(milliseconds: 1500));
    player.stop();
    await tester.pump(const Duration(milliseconds: 5000));

    expect(resolved, isFalse);
    expect(playback.calls, contains('stop'));
  });

  testWidgets('stop before the lead-in elapses never starts the audio',
      (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);

    player.play('51319', intervalMs: 1000, leadInMs: 1000);
    await tester.pump(const Duration(milliseconds: 500));
    player.stop();
    await tester.pump(const Duration(milliseconds: 5000));

    expect(playback.calls, isNot(contains('start')));
  });

  testWidgets('a second play retires the first', (tester) async {
    final playback = FakeAudioPlayback();
    final player = DigitSequencePlayer(playback: playback);
    var firstResolved = false;

    player
        .play('99999', intervalMs: 1000, leadInMs: 0)
        .then((_) => firstResolved = true);
    await tester.pump(const Duration(milliseconds: 1500));

    final second = player.play('51', intervalMs: 1000, leadInMs: 0);
    await tester.pump(const Duration(milliseconds: 2300));
    await second;

    expect(firstResolved, isFalse);
    expect(playback.calls.where((c) => c.startsWith('load:')).length, 2);
  });
}

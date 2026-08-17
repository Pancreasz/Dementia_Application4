import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/asr_segment.dart';
import 'package:moca_main/scoring/score_item.dart';

void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  test('routes digit span to its scorer', () {
    final outcome = scoreItem(spec('digit-span-forward'),
        transcript: 'สองหนึ่งแปดห้าสี่');
    expect(outcome.score, 1);
  });

  test('routes abstraction to its scorer, per item', () {
    expect(scoreItem(spec('abstraction-1'), transcript: 'ยานพาหนะ').score, 1);
    expect(scoreItem(spec('abstraction-2'), transcript: 'ยานพาหนะ').score, 0);
  });

  test('routes orientation, using the reference date it is given', () {
    final outcome = scoreItem(
      spec('orientation'),
      transcript: 'ปี 2569',
      referenceDate: DateTime(2026, 8, 13),
    );
    expect(outcome.detail['year'], isTrue);
  });

  // Vigilance is the only scorer whose answer is not speech: the transcript is
  // always empty and the response arrives as tap offsets.
  test('routes vigilance, scoring taps rather than speech', () {
    final taps = <int>[];
    final sequence = spec('vigilance').sequence!;
    for (var i = 0; i < sequence.length; i++) {
      if (sequence[i] == '1') taps.add(i * 1000 + 400);
    }

    final outcome = scoreItem(spec('vigilance'), taps: taps);
    expect(outcome.score, 1);
    expect(outcome.detail['hits'], 11);
  });

  test('routes sentence repetition against its expected sentence', () {
    final s = spec('sentence-repetition-1');
    final outcome =
        scoreItem(s, transcript: s.expectedSentence!);
    expect(outcome.score, 1);
  });

  test('routes verbal fluency, counting segments', () {
    final segments = [
      for (var i = 0; i < 11; i++)
        AsrSegment(start: i * 2.0, end: i * 2.0 + 1, text: 'ก$i'),
    ];
    final outcome = scoreItem(spec('verbal-fluency'), segments: segments);
    expect(outcome.score, 1);
  });

  test('throws for a subtest with no scorer registered', () {
    const rogue = SubtestSpec(
      id: 'not-a-subtest',
      section: 'x',
      instructionTh: 'x',
      maxScore: 1,
    );
    expect(() => scoreItem(rogue), throwsA(isA<ArgumentError>()));
  });
}

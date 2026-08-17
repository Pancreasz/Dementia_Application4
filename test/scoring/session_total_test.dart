import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/session_total.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  SubtestOutcome full(String id, int score, int max) =>
      SubtestOutcome(subtestId: id, score: score, maxScore: max);

  Map<String, SubtestOutcome> perfectVoice() => {
        'digit-span-forward': full('digit-span-forward', 1, 1),
        'digit-span-backward': full('digit-span-backward', 1, 1),
        'vigilance': full('vigilance', 1, 1),
        'sentence-repetition-1': full('sentence-repetition-1', 1, 1),
        'sentence-repetition-2': full('sentence-repetition-2', 1, 1),
        'verbal-fluency': full('verbal-fluency', 1, 1),
        'abstraction-1': full('abstraction-1', 1, 1),
        'abstraction-2': full('abstraction-2', 1, 1),
        'orientation': full('orientation', 6, 6),
      };

  SessionTotal totalWith(Map<String, SubtestOutcome> voice) =>
      computeSessionTotal(
        larkScore: 1,
        clockScore: 3,
        animalScore: 3,
        attentionScore: 3,
        reorderScore: 5,
        voiceOutcomes: voice,
      );

  test('a perfect session is 29 out of 29', () {
    final total = totalWith(perfectVoice());
    expect(total.score, 29);
    expect(total.maxScore, 29);
  });

  // The attainable ceiling is 29, not 30, because Cube copy is not implemented.
  test('a perfect session still clears the normal cutoff', () {
    expect(totalWith(perfectVoice()).category, 'ปกติ');
  });

  test('classifies MCI, moderate and severe on the published cutoffs', () {
    SessionTotal at(int orientationScore, int fluency) {
      final voice = perfectVoice();
      voice['orientation'] = full('orientation', orientationScore, 6);
      voice['verbal-fluency'] = full('verbal-fluency', fluency, 1);
      return totalWith(voice);
    }

    expect(at(1, 0).score, 23);
    expect(at(1, 0).category, 'บกพร่องเล็กน้อย');
    expect(at(0, 0).score, 22);
  });

  // A skipped subtest is excluded from BOTH sides. Counting it as 0/6 would
  // move a healthy patient across a band on a network failure.
  test('a skipped subtest shrinks the denominator, not just the score', () {
    final voice = perfectVoice();
    voice['orientation'] = SubtestOutcome.skippedFor('orientation');

    final total = totalWith(voice);
    expect(total.score, 23);
    expect(total.maxScore, 23);
    expect(total.skippedIds, ['orientation']);
  });

  // Fixed cutoffs are defined against a complete administration and mean
  // nothing against a partial one. Scaling them proportionally would look
  // helpful and be an invention.
  test('no category is assigned when anything was skipped', () {
    final voice = perfectVoice();
    voice['orientation'] = SubtestOutcome.skippedFor('orientation');

    final total = totalWith(voice);
    expect(total.isComplete, isFalse);
    expect(total.category, isNull);
  });

  test('a subtest never reached counts as skipped', () {
    final voice = perfectVoice()..remove('orientation');

    final total = totalWith(voice);
    expect(total.maxScore, 23);
    expect(total.category, isNull);
  });

  test('band boundaries map to the published MoCA categories', () {
    String? categoryFor(int score) =>
        SessionTotal(score: score, maxScore: 29, skippedIds: const []).category;

    // >= 26 normal
    expect(categoryFor(29), 'ปกติ');
    expect(categoryFor(26), 'ปกติ');
    // 18-25 MCI
    expect(categoryFor(25), 'บกพร่องเล็กน้อย');
    expect(categoryFor(18), 'บกพร่องเล็กน้อย');
    // 10-17 moderate
    expect(categoryFor(17), 'มีความบกพร่อง');
    expect(categoryFor(10), 'มีความบกพร่อง');
    // < 10 severe
    expect(categoryFor(9), 'เสี่ยงสูง');
    expect(categoryFor(0), 'เสี่ยงสูง');
  });

  test('no category is assigned at any score when something was skipped', () {
    for (final score in [29, 26, 18, 10, 0]) {
      expect(
        SessionTotal(score: score, maxScore: 23, skippedIds: const ['orientation']).category,
        isNull,
      );
    }
  });
}

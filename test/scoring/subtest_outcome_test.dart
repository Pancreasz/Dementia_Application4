import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  test('an administered outcome carries its score and max', () {
    const outcome = SubtestOutcome(
      subtestId: 'digit-span-forward',
      score: 1,
      maxScore: 1,
      transcript: 'สองหนึ่งแปดห้าสี่',
    );

    expect(outcome.score, 1);
    expect(outcome.maxScore, 1);
    expect(outcome.skipped, isFalse);
  });

  // A skipped subtest was never administered, so it scores nothing rather than
  // scoring 0 — 0 would assert the patient failed. maxScore 0 keeps it out of
  // both sides of the total.
  test('a skipped outcome scores nothing out of nothing', () {
    final outcome = SubtestOutcome.skippedFor('orientation');

    expect(outcome.skipped, isTrue);
    expect(outcome.score, 0);
    expect(outcome.maxScore, 0);
  });
}

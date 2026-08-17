import 'matchers.dart';
import 'subtest_outcome.dart';

/// One point for repeating the sequence exactly. No partial credit — MoCA
/// scores the item, not the digits.
SubtestOutcome scoreDigitSpan(
  String subtestId,
  String transcript,
  String expectedSequence,
) {
  final spoken = extractDigitSequence(transcript);
  final correct = spoken == expectedSequence;

  return SubtestOutcome(
    subtestId: subtestId,
    score: correct ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'spoken': spoken, 'expected': expectedSequence},
  );
}

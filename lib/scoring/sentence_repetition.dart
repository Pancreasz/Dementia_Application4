import 'dart:math';

import 'matchers.dart';
import 'subtest_outcome.dart';

/// MoCA scores repetition verbatim: any omission or substitution is 0. Against
/// speech-recognizer output, strict equality fails correct patients on
/// recognizer error rather than on memory, so a near-match is accepted.
///
/// 0.9 is a judgement call, not a validated figure. It tolerates roughly one
/// wrong character in ten. Revisit it once real Thai speech has been run
/// through the endpoint — until then, treat this point as provisional.
const _acceptThreshold = 0.9;

/// Levenshtein distance, normalized to a 0..1 similarity.
///
/// Character-level rather than word-level on purpose: Thai does not space
/// between words, so word tokenization is not available here.
double similarityRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;

  final distance = _levenshtein(a, b);
  final longest = max(a.length, b.length);
  return 1.0 - (distance / longest);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Two rows rather than a full matrix: the sentences are short, but there is
  // no reason to allocate length*length when length*2 does.
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      current[j + 1] = min(substitution, min(insertion, deletion));
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[b.length];
}

SubtestOutcome scoreSentenceRepetition(
  String subtestId,
  String transcript,
  String expectedSentence,
) {
  final similarity =
      similarityRatio(normalizeText(transcript), normalizeText(expectedSentence));

  return SubtestOutcome(
    subtestId: subtestId,
    score: similarity >= _acceptThreshold ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {'similarity': similarity, 'expected': expectedSentence},
  );
}

import 'asr_segment.dart';
import 'matchers.dart';
import 'subtest_outcome.dart';

/// The MoCA cutoff: 11 or more words in 60 seconds earns the point.
const int kFluencyWordThreshold = 11;

/// Counts distinct words from segments rather than from the joined transcript.
///
/// This is the whole design of this scorer. Thai does not space between words
/// and the recognizer's spacing is arbitrary, so splitting text on whitespace
/// would count an unpredictable number of "words" for the same speech.
/// Segments key off the patient's own pauses instead, which is what the
/// instrument is actually measuring.
///
/// [initialLetter] filters to words beginning with that letter, for a letter
/// fluency prompt. Pass null for a category prompt, where every word counts.
SubtestOutcome scoreVerbalFluency(
  List<AsrSegment> segments, {
  String? initialLetter,
}) {
  final seen = <String>{};
  final words = <String>[];

  for (final segment in segments) {
    final word = normalizeText(segment.text);
    if (word.isEmpty) continue;
    if (initialLetter != null && !word.startsWith(normalizeText(initialLetter))) {
      continue;
    }
    if (seen.add(word)) words.add(word);
  }

  return SubtestOutcome(
    subtestId: 'verbal-fluency',
    score: words.length >= kFluencyWordThreshold ? 1 : 0,
    maxScore: 1,
    transcript: segments.map((s) => s.text).join(' '),
    detail: {
      'distinctCount': words.length,
      'words': words,
      'threshold': kFluencyWordThreshold,
    },
  );
}

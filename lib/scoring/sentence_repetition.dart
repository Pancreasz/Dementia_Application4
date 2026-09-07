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
///
/// Public and written into every outcome's `detail` so the analysis page can
/// state the threshold a score was measured against rather than repeating the
/// number in its own text, where it could drift away from this one silently.
const double kSentenceSimilarityThreshold = 0.9;

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

const _tensWords = <String, int>{
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
  'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
};
const _teenWords = <String, int>{
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
  'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _onesWords = <String, int>{
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
  'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
};

/// Whisper renders a spoken number as digits or as words inconsistently —
/// the English MoCA sentence "the thirty-three thieves" came back transcribed
/// as "the 33 thieves". Left alone, that mismatch alone can cost the point
/// (each edit is measured against a ~50-character sentence with only 0.10 of
/// headroom). Rewriting spelled-out English numbers to digits before
/// comparing makes the two forms equal regardless of which way the
/// recognizer happened to render them.
///
/// Order matters: compound tens+ones ("thirty-three") first, then bare tens
/// ("eighty") before bare ones ("eight") — otherwise "eight" would match
/// inside "eighty" before the tens pass gets to it. Teens before ones for the
/// same reason ("nineteen" contains "nine").
String _spellOutNumbersAsDigits(String text) {
  // Expects already-lowercased input (normalizeText runs before this).
  var result = text;
  final compound = RegExp(
    '(${_tensWords.keys.join('|')})[\\s-]?(${_onesWords.keys.where((k) => k != 'zero').join('|')})',
  );
  result = result.replaceAllMapped(compound, (m) {
    final value = _tensWords[m.group(1)]! + _onesWords[m.group(2)]!;
    return value.toString();
  });
  for (final words in [_tensWords, _teenWords, _onesWords]) {
    for (final entry in words.entries) {
      result = result.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value.toString());
    }
  }
  return result;
}

/// Thai does not space between words, so where the recognizer puts spaces is
/// arbitrary — the same utterance comes back as "…ช่วยงานวันนี้" one run and
/// "…ช่วยงาน วันนี้" the next, and changing the decoding options changed it for
/// every clip at once. Each stray space is an edit against a ~50-character
/// sentence, so two of them move the similarity by 0.04 with only 0.10 of
/// headroom to begin with: whitespace alone could decide the point.
///
/// Removed rather than collapsed. `normalizeText` collapses runs to a single
/// space, which is the right thing for languages where a space is a word
/// boundary and the wrong thing here.
///
/// Punctuation goes for the same reason, and was found the same way. The
/// English model added on 2026-09-08 returns
/// "How can a clam cram? In a clean cream can..." for a clip of "How can a
/// clam cram in a clean cream can" — a verbatim match plus a question mark and
/// an ellipsis the speaker never uttered. Four invented characters against a
/// 31-character sentence is 0.886 similarity, under the 0.90 threshold, so the
/// patient scored 0 for repeating it perfectly.
///
/// This can only ever move a score UP, because it deletes characters that were
/// never spoken by anyone: it cannot make a wrong answer look right, only stop
/// the recognizer's typography from costing a right one.
///
/// Applied AFTER [_spellOutNumbersAsDigits], which still needs the hyphen in
/// "thirty-three" to be there when it runs.
final RegExp _punctuation = RegExp(r'''[.,!?;:'"“”‘’()\[\]{}…–—\-/\\]''');

String _forComparison(String text) => _spellOutNumbersAsDigits(normalizeText(text))
    .replaceAll(_punctuation, '')
    .replaceAll(RegExp(r'\s+'), '');

SubtestOutcome scoreSentenceRepetition(
  String subtestId,
  String transcript,
  String expectedSentence,
) {
  final similarity =
      similarityRatio(_forComparison(transcript), _forComparison(expectedSentence));

  return SubtestOutcome(
    subtestId: subtestId,
    score: similarity >= kSentenceSimilarityThreshold ? 1 : 0,
    maxScore: 1,
    transcript: transcript,
    detail: {
      'similarity': similarity,
      'expected': expectedSentence,
      'threshold': kSentenceSimilarityThreshold,
    },
  );
}

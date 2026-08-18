import 'asr_segment.dart';
import 'matchers.dart';
import 'subtest_outcome.dart';

/// The MoCA cutoff: 11 or more words in 60 seconds earns the point.
const int kFluencyWordThreshold = 11;

/// Thai vowels written BEFORE the consonant they are pronounced after.
///
/// This is why `"ไก่".startsWith("ก")` is false even though the word plainly
/// begins with the ก sound: the glyph order is ไ-ก-่. A letter-fluency prompt
/// asks for a *sound*, so the comparison has to skip these.
const String _leadingVowels = 'เแโใไ';

/// The first consonant of [word], ignoring any leading vowel.
String _initialConsonant(String word) {
  var i = 0;
  while (i < word.length && _leadingVowels.contains(word[i])) {
    i += 1;
  }
  return i < word.length ? word[i] : '';
}

/// Every whitespace-separated token across all segments, normalized.
///
/// **This is a correction, not the original design.** The scorer used to count
/// one word per segment, on the reasoning that Thai does not space between
/// words and so segments — the patient's own pauses — were the only trustworthy
/// boundary. In practice faster-whisper returns *phrases*, not words: a full
/// 60-second fluency answer came back as a single segment holding all fourteen
/// words, which scored `distinctCount: 0` for a patient who answered well.
///
/// The original worry is still real, and it is now the remaining weakness: if
/// the recognizer returns run-on text with no spaces, this counts it as one
/// word. That under-counts, so it fails a good patient rather than passing a
/// poor one — the safer direction of the two, but not a safe one. Splitting
/// run-on Thai properly needs a word segmenter (e.g. PyThaiNLP server-side).
Iterable<String> _wordsIn(List<AsrSegment> segments) sync* {
  for (final segment in segments) {
    for (final token in segment.text.split(RegExp(r'\s+'))) {
      // Whisper punctuates: "แก้ว." and "แก้ว" are one word, not two.
      final word = normalizeText(token).replaceAll(RegExp(r'[.,!?;:]+$'), '');
      if (word.isNotEmpty) yield word;
    }
  }
}

/// [initialLetter] filters to words beginning with that letter, for a letter
/// fluency prompt. Pass null for a category prompt, where every word counts.
SubtestOutcome scoreVerbalFluency(
  List<AsrSegment> segments, {
  String? initialLetter,
}) {
  final seen = <String>{};
  final words = <String>[];
  final rejected = <String>[];

  final wanted =
      initialLetter == null ? null : _initialConsonant(normalizeText(initialLetter));

  for (final word in _wordsIn(segments)) {
    if (wanted != null && _initialConsonant(word) != wanted) {
      rejected.add(word);
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
      // Printed by score_log.dart. A patient who is sure they answered well
      // needs to see which words were thrown away and why.
      if (rejected.isNotEmpty) 'rejectedWrongLetter': rejected,
    },
  );
}

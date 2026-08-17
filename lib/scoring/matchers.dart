/// Text matching shared by every voice scorer.
///
/// Ported from ad_hw/src/main/scoring/matchers.js.

String normalizeText(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool keywordMatch(String transcript, List<String> acceptedKeywords) {
  final normalized = normalizeText(transcript);
  return acceptedKeywords.any((k) => normalized.contains(normalizeText(k)));
}

const _thaiDigitWords = <String, String>{
  'ศูนย์': '0',
  'หนึ่ง': '1',
  'สอง': '2',
  'สาม': '3',
  'สี่': '4',
  'ห้า': '5',
  'หก': '6',
  'เจ็ด': '7',
  'แปด': '8',
  'เก้า': '9',
};

/// Longest first, so a shorter word can never shadow a longer one that starts
/// with the same characters.
final List<MapEntry<String, String>> _thaiDigitEntries =
    _thaiDigitWords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

/// Thai numerals ๐-๙, in value order.
const _thaiNumerals = '๐๑๒๓๔๕๖๗๘๙';

/// Scans the transcript character by character rather than splitting on
/// whitespace. Thai does not space between words, so whether the recognizer
/// returns "สอง สี่ เจ็ด" or "สองสี่เจ็ด" for the same utterance is arbitrary
/// — and the whitespace-splitting version scored the run-on form as no digits
/// at all, silently marking a correct answer wrong. Scanning handles spaced,
/// run-on and mixed forms identically, plus Thai and Arabic numerals.
String extractDigitSequence(String transcript) {
  final normalized = normalizeText(transcript);
  final digits = StringBuffer();

  var i = 0;
  while (i < normalized.length) {
    final char = normalized[i];

    if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0) {
      digits.write(char);
      i += 1;
      continue;
    }

    final numeral = _thaiNumerals.indexOf(char);
    if (numeral != -1) {
      digits.write(numeral.toString());
      i += 1;
      continue;
    }

    MapEntry<String, String>? word;
    for (final entry in _thaiDigitEntries) {
      if (normalized.startsWith(entry.key, i)) {
        word = entry;
        break;
      }
    }
    if (word != null) {
      digits.write(word.value);
      i += word.key.length;
      continue;
    }

    i += 1;
  }

  return digits.toString();
}

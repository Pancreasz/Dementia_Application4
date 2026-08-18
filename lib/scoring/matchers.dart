/// Text matching shared by every voice scorer.
///
/// Ported from ad_hw/src/main/scoring/matchers.js.
library;

String normalizeText(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Thai has no spaces between words, so any space in a keyword or transcript
/// is an ASR artifact, not a token boundary. Stripped rather than collapsed
/// to a single space (as `normalizeText` does) for the same reason
/// `sentence_repetition.dart` strips: a stray space would otherwise split a
/// compound word in two and break the substring match, scoring a correct
/// answer wrong (e.g. "วันอังคาร" heard as "วัน อังคาร").
String _stripWhitespace(String text) => text.replaceAll(RegExp(r'\s+'), '');

bool keywordMatch(String transcript, List<String> acceptedKeywords) {
  final normalized = _stripWhitespace(normalizeText(transcript));
  return acceptedKeywords.any(
    (k) => normalized.contains(_stripWhitespace(normalizeText(k))),
  );
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

/// The Thai *compound* number word(s) for `value` (0-99), as actually spoken
/// for a calendar date — "nineteen" is "สิบเก้า" (สิบ=ten + เก้า=nine), not a
/// digit-by-digit reading. `_thaiDigitWords` only covers single digits 0-9,
/// which is one accepted reading of the year (see `thaiFullNumberWordVariants`
/// for the other) but always wrong for a 1-31 calendar date, which is never
/// read digit-by-digit.
///
/// Returns every accepted spoken form so a scorer can match any of them.
/// The teen/twenty irregularity (เอ็ด instead of หนึ่ง for a trailing 1) is
/// real Thai grammar, not a typo: ยี่สิบเอ็ด (21), never ยี่สิบหนึ่ง in
/// standard speech, though some speakers do say it that way, so both are
/// accepted.
List<String> thaiCompoundNumberWords(int value) {
  const ones = [
    'ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า',
  ];
  if (value < 0 || value > 99) return const [];
  if (value < 10) return [ones[value]];

  final tens = value ~/ 10;
  final unit = value % 10;
  final tensWord = switch (tens) {
    1 => 'สิบ',
    2 => 'ยี่สิบ',
    _ => '${ones[tens]}สิบ',
  };
  if (unit == 0) return [tensWord];
  if (unit == 1) return ['$tensWordเอ็ด', '$tensWordหนึ่ง'];
  return ['$tensWord${ones[unit]}'];
}

/// True if `normalized` contains `value` (0-99) spoken as a Thai compound
/// number word, e.g. 19 -> "สิบเก้า". `normalized` should already be the
/// output of `normalizeText`; whitespace is stripped here for the same
/// reason `keywordMatch` strips it — a stray ASR space inside the compound
/// word ("สิบ เก้า") is an artifact, not a real boundary.
bool thaiCompoundNumberStated(String normalized, int value) {
  final stripped = _stripWhitespace(normalized);
  for (final word in thaiCompoundNumberWords(value)) {
    var start = 0;
    while (true) {
      final idx = stripped.indexOf(word, start);
      if (idx == -1) break;
      if (!_precededByDecadeMultiplier(stripped, idx)) return true;
      start = idx + 1;
    }
  }
  return false;
}

/// True if a decade-multiplying digit word (2-9) sits immediately before
/// `index`, meaning the match starting there is actually the tail of a
/// bigger decade number, not a standalone teen. Guards a real collision: the
/// Buddhist Era year is often read as one compound number too (e.g. 2569 ->
/// "...หกสิบเก้า", sixty-nine), and "สิบเก้า" (nineteen) sits inside "หกสิบเก้า"
/// as a literal substring. Without this, a date of 19 could be credited off
/// the year's own text even when the patient never stated the date at all.
bool _precededByDecadeMultiplier(String text, int index) {
  for (final entry in _thaiDigitWords.entries) {
    // ศูนย์ (0) and หนึ่ง (1) are never valid decade multipliers in Thai -
    // there is no "ศูนย์สิบ" or "หนึ่งสิบ", only bare "สิบ" for ten.
    if (entry.value == '0' || entry.value == '1') continue;
    final start = index - entry.key.length;
    if (start >= 0 && text.substring(start, index) == entry.key) return true;
  }
  return false;
}

/// Reverse of `_thaiDigitWords`, for reading a number out digit-by-digit.
final Map<String, String> _digitToThaiWord = {
  for (final e in _thaiDigitWords.entries) e.value: e.key,
};

/// The Buddhist Era year, spoken digit-by-digit: 2569 -> "สอง ห้า หก เก้า".
/// This is the administration the MoCA form actually calls for.
String thaiDigitByDigitWords(String digits) =>
    digits.split('').map((d) => _digitToThaiWord[d] ?? '').join();

/// A 0-9999 value read as one compound number word using standard Thai place
/// value naming (หน่วย/สิบ/ร้อย/พัน), e.g. 2569 -> "สองพันห้าร้อยหกสิบเก้า".
/// Patients don't reliably use the digit-by-digit reading the form expects —
/// this is the other real way a Thai speaker states a 4-digit year.
///
/// Two irregularities are real Thai grammar, not typos: at the tens place, 2
/// is "ยี่" not "สอง" (ยี่สิบ, never สองสิบ); the bare tens digit 1 (สิบ) has
/// no leading digit word (สิบ, never หนึ่งสิบ). At the units place, a
/// trailing 1 is "เอ็ด" rather than "หนึ่ง" whenever a higher place is
/// present (a bare 1 is still "หนึ่ง").
String _thaiFullNumberWords(int value) {
  if (value == 0) return 'ศูนย์';
  const ones = [
    'ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า',
  ];
  const places = ['พัน', 'ร้อย', 'สิบ', ''];
  final digits = value.toString().padLeft(4, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < 4; i++) {
    final d = int.parse(digits[i]);
    if (d == 0) continue;
    final String word;
    if (i == 2 && d == 2) {
      word = 'ยี่';
    } else if (i == 2 && d == 1) {
      word = '';
    } else if (i == 3 && d == 1 && value > 9) {
      word = 'เอ็ด';
    } else {
      word = ones[d];
    }
    buffer
      ..write(word)
      ..write(places[i]);
  }
  return buffer.toString();
}

/// Every accepted spoken form of a 0-9999 value: the digit-by-digit reading,
/// the full compound-word reading, and (when the compound form ends in
/// เอ็ด) the alternate หนึ่ง ending some speakers use instead.
List<String> thaiFullNumberWordVariants(int value) {
  if (value < 0 || value > 9999) return const [];
  final digitByDigit = thaiDigitByDigitWords(value.toString());
  final compound = _thaiFullNumberWords(value);
  final variants = <String>{digitByDigit, compound};
  if (compound.contains('เอ็ด')) {
    variants.add(compound.replaceAll('เอ็ด', 'หนึ่ง'));
  }
  return variants.toList();
}

/// True if `normalized` contains `value` (0-9999) spoken in any accepted
/// Thai form — digit-by-digit or as one compound number word. Whitespace is
/// stripped for the same reason `thaiCompoundNumberStated` strips it.
bool thaiFullNumberStated(String normalized, int value) {
  final stripped = _stripWhitespace(normalized);
  return thaiFullNumberWordVariants(value).any(stripped.contains);
}

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

import 'matchers.dart';
import 'subtest_outcome.dart';

const _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const _thaiDays = [
  'วันจันทร์',
  'วันอังคาร',
  'วันพุธ',
  'วันพฤหัสบดี',
  'วันศุกร์',
  'วันเสาร์',
  'วันอาทิตย์',
];

/// Matches a number as a standalone value rather than as a substring.
///
/// The date is 1-2 digits and the Buddhist Era year is 4, so a bare substring
/// match hands the date point to any patient who merely states the year:
/// "2569" contains "6", so the 6th of any month in BE 2569 scores for free —
/// and a patient who states the WRONG date still scores when its digit happens
/// to appear in the year. Digit boundaries close both.
bool _numberStated(String normalized, String number) =>
    RegExp('(?<!\\d)${RegExp.escape(number)}(?!\\d)').hasMatch(normalized);

/// Like `_numberStated`, but also accepts a calendar date of 10-31 spoken as
/// a Thai compound number word ("สิบเก้า" for 19) rather than Arabic digits.
/// Whisper renders spoken numbers as digits or as words inconsistently
/// between takes of the *same* utterance, so a patient who says the date
/// correctly can still fail a digits-only check depending on which way the
/// transcription happened to fall.
///
/// Deliberately NOT extended below 10: a single Thai digit word (e.g. "เก้า"
/// for 9) is also the *suffix* of every teen/twenty/thirty word ("สิบเก้า",
/// "ยี่สิบเก้า"), and the Buddhist Era year is routinely read digit-by-digit
/// ("สอง ห้า หก เก้า" for 2569) right there in the same answer. Matching a
/// bare single-digit word would let the year's last digit falsely satisfy an
/// unrelated single-digit date. The 10+ compound forms don't have this
/// problem: "สิบ"/"ยี่สิบ"/"สามสิบ" is a distinctive prefix no digit-by-digit
/// year reading produces.
bool _dateStated(String normalized, int day) =>
    _numberStated(normalized, day.toString()) ||
    (day >= 10 && thaiCompoundNumberStated(normalized, day));

/// Like `_numberStated`, but also accepts the Buddhist Era year spoken as
/// Thai words — either digit-by-digit ("สอง ห้า หก เก้า" for 2569, the
/// administration the form calls for) or as one compound number word
/// ("สองพันห้าร้อยหกสิบเก้า"), which is how Thai speakers actually say a year
/// in ordinary speech. Whisper renders the same spoken year as digits or as
/// words inconsistently between takes, so a digits-only check silently fails
/// a correct answer depending on which way the transcription happened to
/// fall — the same failure mode already fixed for the date.
bool _yearStated(String normalized, int year) =>
    _numberStated(normalized, year.toString()) ||
    thaiFullNumberStated(normalized, year);

/// Six independent items, one point each. Note the year is Buddhist Era
/// (Gregorian + 543), as Thai MoCA forms use.
SubtestOutcome scoreOrientation(
  String transcript, {
  required DateTime referenceDate,
  required String place,
  required String province,
}) {
  // Dart's DateTime.weekday is 1 = Monday … 7 = Sunday, which is why _thaiDays
  // starts at Monday rather than Sunday.
  final items = <String, String>{
    'day': _thaiDays[referenceDate.weekday - 1],
    'month': _thaiMonths[referenceDate.month - 1],
    'year': (referenceDate.year + 543).toString(),
    'date': referenceDate.day.toString(),
    'place': place,
    'province': province,
  };

  final normalized = normalizeText(transcript);

  final detail = <String, dynamic>{};
  var score = 0;
  items.forEach((key, expected) {
    final bool correct;
    switch (key) {
      case 'date':
        correct = _dateStated(normalized, referenceDate.day);
      case 'year':
        correct = _yearStated(normalized, referenceDate.year + 543);
      default:
        correct = keywordMatch(normalized, [expected]);
    }
    detail[key] = correct;
    if (correct) score += 1;
  });

  return SubtestOutcome(
    subtestId: 'orientation',
    score: score,
    maxScore: 6,
    transcript: transcript,
    detail: detail,
  );
}

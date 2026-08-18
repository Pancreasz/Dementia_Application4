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
  const numericKeys = {'date', 'year'};

  final detail = <String, dynamic>{};
  var score = 0;
  items.forEach((key, expected) {
    final correct = numericKeys.contains(key)
        ? _numberStated(normalized, expected)
        : keywordMatch(normalized, [expected]);
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

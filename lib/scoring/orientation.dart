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

  final detail = <String, dynamic>{};
  var score = 0;
  items.forEach((key, expected) {
    final correct = keywordMatch(transcript, [expected]);
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

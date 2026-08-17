import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/orientation.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  // August 13, 2026 — a Thursday.
  final referenceDate = DateTime(2026, 8, 13);
  const place = 'โรงพยาบาลศิริราช';
  const province = 'กรุงเทพ';

  SubtestOutcome score(String transcript) => scoreOrientation(
        transcript,
        referenceDate: referenceDate,
        place: place,
        province: province,
      );

  test('awards full 6/6 when all six items are stated correctly', () {
    final outcome = score(
        'วันนี้วันพฤหัสบดี เดือนสิงหาคม ปี 2569 วันที่ 13 อยู่ที่โรงพยาบาลศิริราช จังหวัดกรุงเทพ');
    expect(outcome.score, 6);
    expect(outcome.maxScore, 6);
  });

  test('awards partial credit for a partially correct answer', () {
    final outcome = score('วันนี้วันพฤหัสบดี เดือนสิงหาคม');
    expect(outcome.score, 2);
    expect(outcome.detail['day'], isTrue);
    expect(outcome.detail['month'], isTrue);
    expect(outcome.detail['year'], isFalse);
  });

  // Thai MoCA forms use the Buddhist Era, not the Gregorian year.
  test('expects the Buddhist Era year (CE + 543)', () {
    final outcome = score('ปี 2569');
    expect(outcome.detail['year'], isTrue);
  });

  test('rejects the Gregorian year', () {
    final outcome = score('ปี 2026');
    expect(outcome.detail['year'], isFalse);
  });

  test('awards 0/6 for an unrelated answer', () {
    expect(score('ไม่ทราบ').score, 0);
  });
}

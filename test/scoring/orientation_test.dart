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

  // Regression coverage for the substring-match bug: a bare .contains() match
  // hands the date point to anyone who states only the (4-digit) Buddhist Era
  // year, because the 1-2 digit date is frequently a substring of it.
  group('date must be stated, not merely implied by the year', () {
    test('reference 2026-08-06: stating only the year does not score the date',
        () {
      // BE year is 2569. "2569".contains("6") is true, so a substring
      // matcher awards the date for free on the 6th.
      final outcome = scoreOrientation(
        'ปี 2569',
        referenceDate: DateTime(2026, 8, 6),
        place: 'โรงพยาบาลศิริราช',
        province: 'กรุงเทพ',
      );
      expect(outcome.detail['date'], isFalse);
    });

    test(
        'reference 2026-08-06: stating the WRONG date does not score, even '
        'though its digit appears in the year', () {
      final outcome = scoreOrientation(
        'วันที่ 7 ปี 2569',
        referenceDate: DateTime(2026, 8, 6),
        place: 'โรงพยาบาลศิริราช',
        province: 'กรุงเทพ',
      );
      expect(outcome.detail['date'], isFalse);
      expect(outcome.detail['year'], isTrue);
    });

    test('reference 2026-08-06: stating the correct date and year scores both',
        () {
      final outcome = scoreOrientation(
        'วันที่ 6 ปี 2569',
        referenceDate: DateTime(2026, 8, 6),
        place: 'โรงพยาบาลศิริราช',
        province: 'กรุงเทพ',
      );
      expect(outcome.detail['date'], isTrue);
      expect(outcome.detail['year'], isTrue);
    });

    test('reference 2026-08-25: stating only the year does not score the date',
        () {
      // "2569".contains("25") is also true.
      final outcome = scoreOrientation(
        'ปี 2569',
        referenceDate: DateTime(2026, 8, 25),
        place: 'โรงพยาบาลศิริราช',
        province: 'กรุงเทพ',
      );
      expect(outcome.detail['date'], isFalse);
    });

    test('reference 2026-08-05: "15" must not match a stated date of 5', () {
      final outcome = scoreOrientation(
        'วันที่ 15',
        referenceDate: DateTime(2026, 8, 5),
        place: 'โรงพยาบาลศิริราช',
        province: 'กรุงเทพ',
      );
      expect(outcome.detail['date'], isFalse);
    });
  });
}

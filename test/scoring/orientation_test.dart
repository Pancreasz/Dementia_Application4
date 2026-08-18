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

  // Regression coverage: Thai has no spaces between words, so a stray space
  // the ASR inserts inside a compound word (e.g. "วันอังคาร" heard as
  // "วัน อังคาร") is an artifact, not a real token boundary. A bare
  // .contains() breaks on it and scores a correct answer wrong.
  test('day is scored correct even when the ASR inserts a stray space inside it',
      () {
    final outcome = scoreOrientation(
      'วัน อังคาร เดือน สิงหาคม ปี 2569 วันที่ 19 สถานที่โรงพยาบาล',
      referenceDate: DateTime(2026, 8, 18), // a Tuesday
      place: place,
      province: province,
    );
    expect(outcome.detail['day'], isTrue);
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

  // Regression coverage for a real session (2026-08-19): Whisper transcribed
  // a correctly-spoken date as the Thai word "สิบเก้า" (nineteen) instead of
  // the digit "19". The old digits-only _numberStated check scored this
  // wrong even though the patient answered correctly.
  group('date spoken as a Thai compound number word', () {
    test('a teen date is scored correct when Whisper spells it out', () {
      final outcome = scoreOrientation(
        'วัน อังคาร เดือน สิงหาคม ปี 2569 วันที่ สิบเก้า สถานที่โรงพยาบาลศิริราช จังหวัด กรุงเทพ',
        referenceDate: DateTime(2026, 8, 19), // a Wednesday
        place: place,
        province: province,
      );
      expect(outcome.detail['day'], isFalse);
      expect(outcome.detail['date'], isTrue);
      expect(outcome.score, 5);
    });

    test('a single-digit date is NOT credited by an unrelated digit inside '
        "the year's digit-by-digit reading", () {
      // Year read digit-by-digit ends in "เก้า" (9). Reference day is also 9.
      // A bare substring match on the single-digit word would wrongly credit
      // the date here even though the patient never stated it separately.
      final outcome = scoreOrientation(
        'ปี สอง ห้า หก เก้า',
        referenceDate: DateTime(2026, 8, 9),
        place: place,
        province: province,
      );
      expect(outcome.detail['date'], isFalse);
    });
  });

  // Regression coverage for a real session (2026-08-19): the patient spoke
  // the Buddhist Era year as one compound number word ("สองพันห้าร้อยหกสิบเก้า")
  // instead of digit-by-digit, and Whisper transcribed it that way. The old
  // digits-only _numberStated check scored the year wrong even though the
  // patient answered correctly.
  group('year spoken as a Thai number word', () {
    test('a full compound reading of the year is scored correct', () {
      final outcome = scoreOrientation(
        'วัน อังคาร เดือน สิงหาคม ปี สองพันห้าร้อยหกสิบเก้า วันที่ สิบเก้า '
        'กรุงเทพมหานคร โรงพยาบาลศิริราช',
        referenceDate: DateTime(2026, 8, 19), // a Wednesday
        place: place,
        province: province,
      );
      expect(outcome.detail['year'], isTrue);
      expect(outcome.detail['date'], isTrue);
    });

    test('a digit-by-digit reading of the year is still scored correct', () {
      final outcome = scoreOrientation(
        'ปี สอง ห้า หก เก้า',
        referenceDate: DateTime(2026, 8, 6),
        place: place,
        province: province,
      );
      expect(outcome.detail['year'], isTrue);
    });

    // The year's own compound reading can contain a teen date as a literal
    // substring ("...หกสิบเก้า" contains "สิบเก้า"). A date must not be
    // credited off the year's text when the patient never stated it.
    test(
        "a teen date is NOT credited by the year's own compound reading "
        'when the patient never separately states the date', () {
      final outcome = scoreOrientation(
        'ปี สองพันห้าร้อยหกสิบเก้า',
        referenceDate: DateTime(2026, 8, 19),
        place: place,
        province: province,
      );
      expect(outcome.detail['year'], isTrue);
      expect(outcome.detail['date'], isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/abstraction.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

void main() {
  group('scoreAbstraction for รถไฟ–จักรยาน', () {
    SubtestOutcome score(String t) => scoreAbstraction('abstraction-1', t);

    test('accepts the category itself', () {
      expect(score('ยานพาหนะ').score, 1);
    });

    test('accepts the shortened form a patient is likelier to say', () {
      expect(score('เป็นพาหนะ').score, 1);
    });

    test('accepts a travel answer, which the instrument allows', () {
      expect(score('ใช้เดินทาง').score, 1);
    });

    // MoCA scores the abstract category, not a shared physical feature.
    test('rejects the concrete answer about wheels', () {
      expect(score('มีล้อเหมือนกัน').score, 0);
    });

    // The reason this scorer has no reject-list: a correct abstract answer is
    // allowed to mention a concrete detail too, and stripping the point for it
    // would take away something the patient earned. Do not "harden" this.
    test('accepts an abstract answer that also mentions a concrete detail', () {
      expect(score('เป็นพาหนะที่มีล้อ').score, 1);
    });

    test('scores nothing when the patient only repeats the two items back', () {
      expect(score('รถไฟกับจักรยาน').score, 0);
    });

    test('scores nothing for no answer', () {
      expect(score('').score, 0);
    });
  });

  group('scoreAbstraction for นาฬิกา–ไม้บรรทัด', () {
    SubtestOutcome score(String t) => scoreAbstraction('abstraction-2', t);

    test('accepts the category itself', () {
      expect(score('เครื่องมือวัด').score, 1);
    });

    test('accepts a bare verb answer', () {
      expect(score('ใช้วัด').score, 1);
    });

    test('rejects the concrete answer about numbers', () {
      expect(score('มีตัวเลขเหมือนกัน').score, 0);
    });

    // ไม้บรรทัด ends in ทัด, not วัด. If it did contain the accepted keyword,
    // a patient parroting the question would score a point for saying nothing.
    test('scores nothing when the patient only repeats the two items back', () {
      expect(score('นาฬิกากับไม้บรรทัด').score, 0);
    });
  });

  group('scoreAbstraction across both items', () {
    test('matches a run-on transcript with no spaces', () {
      expect(scoreAbstraction('abstraction-1', 'ทั้งสองอย่างเป็นยานพาหนะครับ').score, 1);
    });

    test('reports which accepted term matched, for checking real speech', () {
      expect(scoreAbstraction('abstraction-1', 'ยานพาหนะ').detail['matched'],
          'ยานพาหนะ');
    });

    test('reports no match when nothing was accepted', () {
      expect(scoreAbstraction('abstraction-1', 'มีล้อ').detail['matched'], isNull);
    });

    // A typo in a subtest id must not silently score every patient zero on an
    // item that was never really administered, and look like a clinical finding.
    test('throws on an unknown item rather than scoring it wrong', () {
      expect(() => scoreAbstraction('abstraction-9', 'ยานพาหนะ'),
          throwsA(isA<ArgumentError>()));
    });

    test('does not let one item answer score the other', () {
      expect(scoreAbstraction('abstraction-1', 'เครื่องมือวัด').score, 0);
      expect(scoreAbstraction('abstraction-2', 'ยานพาหนะ').score, 0);
    });
  });
}

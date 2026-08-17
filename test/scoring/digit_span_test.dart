import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/digit_span.dart';

void main() {
  group('scoreDigitSpan forward', () {
    test('scores 1 for the exact sequence', () {
      final outcome =
          scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปดห้าสี่', '21854');
      expect(outcome.score, 1);
      expect(outcome.maxScore, 1);
    });

    test('scores 0 for a wrong digit', () {
      final outcome =
          scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปดห้าห้า', '21854');
      expect(outcome.score, 0);
    });

    test('scores 0 for silence', () {
      final outcome = scoreDigitSpan('digit-span-forward', '', '21854');
      expect(outcome.score, 0);
    });
  });

  group('scoreDigitSpan backward', () {
    // The patient hears 742 and must say it reversed.
    test('scores 1 for the reversed sequence', () {
      final outcome =
          scoreDigitSpan('digit-span-backward', 'สองสี่เจ็ด', '247');
      expect(outcome.score, 1);
    });

    test('scores 0 when the patient repeats it forward instead', () {
      final outcome =
          scoreDigitSpan('digit-span-backward', 'เจ็ดสี่สอง', '247');
      expect(outcome.score, 0);
    });
  });

  test('records what was heard and what was expected, for review', () {
    final outcome =
        scoreDigitSpan('digit-span-forward', 'สองหนึ่งแปด', '21854');
    expect(outcome.detail['spoken'], '218');
    expect(outcome.detail['expected'], '21854');
    expect(outcome.transcript, 'สองหนึ่งแปด');
  });
}

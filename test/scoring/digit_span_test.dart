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

  group('real distil-whisper output (regression, 2026-09-08)', () {
    // Verbatim from the English ASR model added on 2026-09-08, transcribing
    // the English digit stimuli. Transcripts of what the patient HEARS, not of
    // a patient answering — a proxy for the scorer's input, not evidence about
    // anyone. The point is that both shapes the model produces are extracted
    // correctly, because neither is bare digits.
    test('English digit words are extracted, not just digits', () {
      final outcome = scoreDigitSpan(
          'digit-span-forward', 'Two, one, eight, five, four.', '21854');
      expect(outcome.detail['spoken'], '21854');
      expect(outcome.score, 1);
    });

    test('digits split by stray punctuation are still one sequence', () {
      // "7 4.2" — the decimal point is the recognizer's invention, and
      // splitting on it would drop a digit and score a correct answer 0.
      final outcome = scoreDigitSpan('digit-span-backward', '2.4 7', '247');
      expect(outcome.detail['spoken'], '247');
      expect(outcome.score, 1);
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

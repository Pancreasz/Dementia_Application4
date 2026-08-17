import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/matchers.dart';

void main() {
  group('normalizeText', () {
    test('trims, lowercases, and collapses whitespace', () {
      expect(normalizeText('  Hello   World  '), 'hello world');
    });
  });

  group('keywordMatch', () {
    test('matches if any accepted keyword appears in the transcript', () {
      expect(keywordMatch('I saw a สิงโต today', ['สิงโต', 'lion']), isTrue);
    });

    test('returns false if no accepted keyword appears', () {
      expect(keywordMatch('I saw a cat', ['สิงโต', 'lion']), isFalse);
    });
  });

  group('extractDigitSequence', () {
    test('extracts numeric digits spoken as numerals', () {
      expect(extractDigitSequence('2 1 8 5 4'), '21854');
    });

    test('extracts digits spoken as Thai number words', () {
      expect(extractDigitSequence('สอง หนึ่ง แปด ห้า สี่'), '21854');
    });

    test('handles a mix of numerals and Thai words', () {
      expect(extractDigitSequence('2 หนึ่ง 8 ห้า 4'), '21854');
    });

    // Thai does not put spaces between words, so whether the recognizer returns
    // "สอง สี่ เจ็ด" or "สองสี่เจ็ด" for the same utterance is arbitrary.
    // Splitting on whitespace scored the second form as nothing at all.
    test('extracts digits from Thai number words with no spaces', () {
      expect(extractDigitSequence('สองสี่เจ็ด'), '247');
    });

    test('extracts a longer run-on sequence', () {
      expect(extractDigitSequence('สองหนึ่งแปดห้าสี่'), '21854');
    });

    test('handles a mix of spaced and run-on words', () {
      expect(extractDigitSequence('สอง สี่เจ็ด'), '247');
    });

    test('reads Thai numerals', () {
      expect(extractDigitSequence('๒๔๗'), '247');
      expect(extractDigitSequence('๒ ๑ ๘ ๕ ๔'), '21854');
    });

    test('mixes Thai numerals, Arabic numerals and words', () {
      expect(extractDigitSequence('๒ 4 เจ็ด'), '247');
    });

    test('ignores a trailing politeness particle', () {
      expect(extractDigitSequence('สองสี่เจ็ดครับ'), '247');
    });

    test('covers every digit word run together', () {
      expect(extractDigitSequence('ศูนย์หนึ่งสองสามสี่ห้าหกเจ็ดแปดเก้า'),
          '0123456789');
    });

    test('still returns nothing for speech containing no digits', () {
      expect(extractDigitSequence('ไม่ทราบ'), '');
    });
  });
}

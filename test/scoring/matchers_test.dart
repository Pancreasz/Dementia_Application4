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

    // Documents current behaviour, not a requirement: keywordMatch is bare
    // String.contains with no digit boundaries, so a short numeric keyword
    // matches inside any longer number that contains it as a substring. This
    // is exactly the shape of bug that let Orientation's date item score for
    // free off the Buddhist Era year (see lib/scoring/orientation.dart,
    // _numberStated). keywordMatch itself is unsuitable for numeric matching
    // — callers scoring a number must use a boundary-aware matcher instead.
    test('a short numeric keyword matches inside a longer number', () {
      expect(keywordMatch('ปี 2569', ['6']), isTrue);
      expect(keywordMatch('ปี 2569', ['25']), isTrue);
      expect(keywordMatch('วันที่ 15', ['5']), isTrue);
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

    // Regression: an English-mode digit-span answer can come back from the
    // recognizer as spelled-out words rather than digits.
    test('extracts digits spoken as English number words', () {
      expect(extractDigitSequence('Two, one, eight, five, four.'), '21854');
    });

    test('handles a mix of English words and numerals', () {
      expect(extractDigitSequence('7 four two'), '742');
    });

    test('covers every English digit word', () {
      expect(extractDigitSequence('zero one two three four five six seven eight nine'),
          '0123456789');
    });
  });

  group('thaiCompoundNumberWords', () {
    test('single digits return the bare digit word', () {
      expect(thaiCompoundNumberWords(0), ['ศูนย์']);
      expect(thaiCompoundNumberWords(9), ['เก้า']);
    });

    test('ten is สิบ with no unit', () {
      expect(thaiCompoundNumberWords(10), ['สิบ']);
    });

    test('teens are สิบ + the unit digit', () {
      expect(thaiCompoundNumberWords(19), ['สิบเก้า']);
    });

    test('eleven accepts both เอ็ด and the literal หนึ่ง form', () {
      expect(thaiCompoundNumberWords(11), ['สิบเอ็ด', 'สิบหนึ่ง']);
    });

    test('twenty is the irregular ยี่สิบ, not สองสิบ', () {
      expect(thaiCompoundNumberWords(20), ['ยี่สิบ']);
      expect(thaiCompoundNumberWords(25), ['ยี่สิบห้า']);
    });

    test('thirty and thirty-one use the regular ones-word + สิบ pattern', () {
      expect(thaiCompoundNumberWords(30), ['สามสิบ']);
      expect(thaiCompoundNumberWords(31), ['สามสิบเอ็ด', 'สามสิบหนึ่ง']);
    });
  });

  group('thaiCompoundNumberStated', () {
    test('matches a teen number spoken as one compound word', () {
      expect(thaiCompoundNumberStated(normalizeText('วันที่ สิบเก้า'), 19),
          isTrue);
    });

    test('tolerates a stray ASR space inside the compound word', () {
      expect(
          thaiCompoundNumberStated(normalizeText('วันที่ สิบ เก้า'), 19),
          isTrue);
    });

    test('does not match a different number', () {
      expect(thaiCompoundNumberStated(normalizeText('วันที่ สิบแปด'), 19),
          isFalse);
    });

    // Regression coverage for a real collision: the Buddhist Era year is
    // often read as one compound number ("2569" -> "...หกสิบเก้า", sixty-
    // nine), and "สิบเก้า" (nineteen) sits inside "หกสิบเก้า" as a literal
    // substring. A date of 19 must not be credited off the year's own text.
    test('a teen embedded in a bigger decade number does not count as stated',
        () {
      expect(
          thaiCompoundNumberStated(
              normalizeText('ปี สองพันห้าร้อยหกสิบเก้า'), 19),
          isFalse);
    });

    test('the same teen elsewhere in the transcript still counts', () {
      expect(
          thaiCompoundNumberStated(
              normalizeText('ปี สองพันห้าร้อยหกสิบเก้า วันที่ สิบเก้า'), 19),
          isTrue);
    });
  });

  group('thaiDigitByDigitWords', () {
    test('reads each digit as its own word', () {
      expect(thaiDigitByDigitWords('2569'), 'สองห้าหกเก้า');
    });
  });

  group('thaiFullNumberWordVariants', () {
    test('a 4-digit year as one compound number word', () {
      expect(thaiFullNumberWordVariants(2569),
          containsAll(['สองพันห้าร้อยหกสิบเก้า', 'สองห้าหกเก้า']));
    });

    test('a compound reading ending in เอ็ด also accepts the หนึ่ง variant',
        () {
      expect(thaiFullNumberWordVariants(2511),
          containsAll(['สองพันห้าร้อยสิบเอ็ด', 'สองพันห้าร้อยสิบหนึ่ง']));
    });

    test('the tens-place 2 irregular ยี่ is used, not สอง', () {
      expect(thaiFullNumberWordVariants(2521),
          contains('สองพันห้าร้อยยี่สิบเอ็ด'));
    });
  });

  group('thaiFullNumberStated', () {
    test('matches a year spoken as one compound number word', () {
      expect(
          thaiFullNumberStated(
              normalizeText('ปี สองพันห้าร้อยหกสิบเก้า'), 2569),
          isTrue);
    });

    test('matches a year spoken digit-by-digit', () {
      expect(thaiFullNumberStated(normalizeText('ปี สอง ห้า หก เก้า'), 2569),
          isTrue);
    });

    test('does not match a different year', () {
      expect(
          thaiFullNumberStated(
              normalizeText('ปี สองพันห้าร้อยหกสิบแปด'), 2569),
          isFalse);
    });
  });
}

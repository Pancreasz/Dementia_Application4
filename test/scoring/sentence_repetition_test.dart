import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/sentence_repetition.dart';

void main() {
  // The real sentence 1, so these tests exercise the length and character mix
  // the scorer actually sees. Thai has no word spaces, which is why the
  // similarity is measured per character rather than per word.
  const sentence = 'ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้';

  group('similarityRatio', () {
    test('is 1.0 for identical strings', () {
      expect(similarityRatio('abc', 'abc'), 1.0);
    });

    test('is 0.0 for a completely different string of the same length', () {
      expect(similarityRatio('abc', 'xyz'), 0.0);
    });

    test('is 1.0 for two empty strings', () {
      expect(similarityRatio('', ''), 1.0);
    });

    test('falls between 0 and 1 for a near match', () {
      final ratio = similarityRatio('abcdefghij', 'abcdefghix');
      expect(ratio, greaterThan(0.8));
      expect(ratio, lessThan(1.0));
    });
  });

  group('scoreSentenceRepetition', () {
    test('scores 1 for a verbatim repetition', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', sentence, sentence);
      expect(outcome.score, 1);
      expect(outcome.maxScore, 1);
    });

    test('scores 1 despite a single-character recognizer slip', () {
      // One substituted character out of ~40 is recognizer noise, not a
      // patient error, and strict matching would fail a correct answer.
      // ฉ -> ช is a real substitution: the two are visually and acoustically
      // close, which is exactly the confusion a recognizer makes.
      final heard = sentence.replaceRange(0, 1, 'ช');
      expect(heard, isNot(sentence), reason: 'the slip must actually differ');

      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', heard, sentence);
      expect(outcome.score, 1);
    });

    test('scores 0 when a substantial part is missing', () {
      final heard = sentence.substring(0, sentence.length ~/ 2);
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', heard, sentence);
      expect(outcome.score, 0);
    });

    test('scores 0 for silence', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', '', sentence);
      expect(outcome.score, 0);
    });

    test('records the similarity it measured, for review', () {
      final outcome =
          scoreSentenceRepetition('sentence-repetition-1', sentence, sentence);
      expect(outcome.detail['similarity'], 1.0);
      expect(outcome.detail['expected'], sentence);
    });
  });

  group('spelled-out numbers vs digits (regression, English mode)', () {
    // The real sentence-2 in English mode contains "thirty-three" as a
    // written number, but Whisper transcribed it as "33" — a mismatch that
    // alone dropped the point despite an otherwise-correct repetition.
    const expected = 'How can a clam cram in a clean cream can';
    const expectedSentence2 = 'The thirty-three thieves thought that they thrilled the throne.';

    test('a digit rendering of a spelled-out number does not cost the point', () {
      final outcome = scoreSentenceRepetition(
        'sentence-repetition-2',
        'The 33 thieves thought that they thrilled the throne.',
        expectedSentence2,
      );
      expect(outcome.detail['similarity'], 1.0);
      expect(outcome.score, 1);
    });

    test('an identical repetition still scores 1 when it contains no numbers', () {
      final outcome = scoreSentenceRepetition('sentence-repetition-1', expected, expected);
      expect(outcome.score, 1);
    });

    test('a genuinely wrong number still costs similarity', () {
      final outcome = scoreSentenceRepetition(
        'sentence-repetition-2',
        'The thirty-four thieves thought that they thrilled the throne.',
        expectedSentence2,
      );
      expect(outcome.detail['similarity'], lessThan(1.0));
    });
  });

  group('recognizer whitespace (regression, 2026-08-18)', () {
    // Changing the ASR decoding options to fix digit span changed where the
    // recognizer put spaces in EVERY clip: "…ช่วยงานวันนี้" became
    // "…ช่วยงาน วันนี้". Each stray space is an edit against a ~50-character
    // sentence, and the threshold only has 0.10 of headroom.
    const expected = 'แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง';

    test('spacing the recognizer invented does not cost the point', () {
      final spaced = scoreSentenceRepetition(
        'sentence-repetition-2',
        'แมวมักจะซ่อนตัวอยู่หลังเก้าอี้ เมื่อมีหมา อยู่ในห้อง',
        expected,
      );

      expect(spaced.detail['similarity'], 1.0);
      expect(spaced.score, 1);
    });

    test('a run-on answer and a spaced one score identically', () {
      double sim(String t) =>
          scoreSentenceRepetition('x', t, expected).detail['similarity']
              as double;

      expect(sim('แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง'),
          sim('แมว มักจะ ซ่อนตัว อยู่หลัง เก้าอี้ เมื่อ มีหมา อยู่ในห้อง'));
    });

    test('a genuinely missing word still costs similarity', () {
      // The guard against the above becoming "ignore everything": dropping จะ
      // must still register, since that is the real sentence-2 discrepancy.
      final missing = scoreSentenceRepetition(
        'sentence-repetition-2',
        'แมวมักซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง',
        expected,
      );

      expect(missing.detail['similarity'] as double, lessThan(1.0));
      // Still above threshold — it is one short word — but visibly not perfect.
      expect(missing.detail['similarity'] as double, greaterThan(0.9));
    });
  });
}

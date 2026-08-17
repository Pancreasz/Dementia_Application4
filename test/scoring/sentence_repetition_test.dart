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
}

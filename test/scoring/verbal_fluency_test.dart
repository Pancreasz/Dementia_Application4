import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/asr_segment.dart';
import 'package:moca_main/scoring/verbal_fluency.dart';

void main() {
  List<AsrSegment> segments(List<String> words) => [
        for (var i = 0; i < words.length; i++)
          AsrSegment(start: i * 2.0, end: i * 2.0 + 1.0, text: words[i]),
      ];

  test('scores 1 at the 11-word cutoff', () {
    final words = List.generate(11, (i) => 'คำ$i');
    expect(scoreVerbalFluency(segments(words)).score, 1);
  });

  test('scores 0 just below the cutoff', () {
    final words = List.generate(10, (i) => 'คำ$i');
    expect(scoreVerbalFluency(segments(words)).score, 0);
  });

  test('counts a repeated word only once', () {
    final words = List.generate(11, (i) => 'คำ$i') + ['คำ0', 'คำ1'];
    final outcome = scoreVerbalFluency(segments(words));
    expect(outcome.detail['distinctCount'], 11);
  });

  test('ignores empty and whitespace-only segments', () {
    final words = List.generate(11, (i) => 'คำ$i') + ['', '   '];
    expect(scoreVerbalFluency(segments(words)).detail['distinctCount'], 11);
  });

  test('treats segments differing only in case or padding as one word', () {
    final outcome = scoreVerbalFluency(segments(['Cat', ' cat ', 'CAT']));
    expect(outcome.detail['distinctCount'], 1);
  });

  group('with a letter prompt', () {
    test('counts only words starting with the prompt letter', () {
      final outcome = scoreVerbalFluency(
        segments(['กา', 'กิน', 'ขาย', 'กบ']),
        initialLetter: 'ก',
      );
      expect(outcome.detail['distinctCount'], 3);
    });

    test('scores 0 when too few words start with the prompt letter', () {
      final outcome = scoreVerbalFluency(
        segments(List.generate(20, (i) => 'ขคำ$i')),
        initialLetter: 'ก',
      );
      expect(outcome.score, 0);
    });
  });

  test('records the words it counted, so a human can check the score', () {
    final outcome = scoreVerbalFluency(segments(['กา', 'กิน']));
    expect(outcome.detail['words'], ['กา', 'กิน']);
  });

  test('scores 0 for no speech at all', () {
    final outcome = scoreVerbalFluency(<AsrSegment>[]);
    expect(outcome.score, 0);
    expect(outcome.detail['distinctCount'], 0);
  });

  group('regressions from a real session (2026-08-18)', () {
    // The recognizer returned all fourteen words as ONE segment and the
    // patient scored 0/1 with distinctCount: 0, having answered well. Two
    // independent causes, one test each below, plus the real line.
    const realAnswer =
        'ไก่ กอง กางเกง กุ้ง แก้ว กระหนก กระจู กระเจี้ยว กระจอก กาก กรวย กระดาษ กระดอก กระดูก';

    test('a whole answer arriving as one segment is still counted word by word',
        () {
      final outcome = scoreVerbalFluency(
        [const AsrSegment(start: 0, end: 60, text: realAnswer)],
        initialLetter: 'ก',
      );

      // 14 spoken, all beginning with the ก sound, all distinct.
      expect(outcome.detail['distinctCount'], 14);
      expect(outcome.score, 1);
    });

    test('a leading vowel does not hide the initial consonant', () {
      // ไก่ is written ไ-ก-่, so startsWith('ก') is false while the word
      // plainly begins with the ก sound. Same for แก้ว, เก้าอี้, โกรธ, ใกล้.
      final outcome = scoreVerbalFluency(
        [
          for (final w in ['ไก่', 'แก้ว', 'เก้าอี้', 'โกรธ', 'ใกล้'])
            AsrSegment(start: 0, end: 1, text: w),
        ],
        initialLetter: 'ก',
      );

      expect(outcome.detail['distinctCount'], 5);
      expect(outcome.detail['rejectedWrongLetter'], isNull);
    });

    test('still rejects words that genuinely start with another letter', () {
      // The leading-vowel rule must not become "accept anything": เสือ is
      // เ-ส-ือ, whose initial consonant is ส, not ก.
      final outcome = scoreVerbalFluency(
        [
          for (final w in ['ไก่', 'เสือ', 'กบ', 'แมว'])
            AsrSegment(start: 0, end: 1, text: w),
        ],
        initialLetter: 'ก',
      );

      expect(outcome.detail['distinctCount'], 2);
      expect(outcome.detail['rejectedWrongLetter'], ['เสือ', 'แมว']);
    });

    test('trailing punctuation does not split one word into two', () {
      final outcome = scoreVerbalFluency(
        [const AsrSegment(start: 0, end: 2, text: 'กา กา. กา')],
        initialLetter: 'ก',
      );
      expect(outcome.detail['distinctCount'], 1);
    });

    test('run-on output with no spaces is still under-counted (known limit)', () {
      // Documents the remaining weakness rather than claiming it is solved:
      // with no spaces there is nothing to split on without a Thai word
      // segmenter, so this counts 1 rather than 3. It fails a good patient,
      // which is the safer direction, but it is not safe.
      final outcome = scoreVerbalFluency(
        [const AsrSegment(start: 0, end: 5, text: 'กากองกางเกง')],
        initialLetter: 'ก',
      );
      expect(outcome.detail['distinctCount'], 1);
    });
  });
}

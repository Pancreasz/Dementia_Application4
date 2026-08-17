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
}

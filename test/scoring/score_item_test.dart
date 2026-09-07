import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/similarity_client.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/asr_segment.dart';
import 'package:moca_main/scoring/score_item.dart';

void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  test('routes digit span to its scorer', () async {
    final outcome = await scoreItem(spec('digit-span-forward'),
        transcript: 'สองหนึ่งแปดห้าสี่');
    expect(outcome.score, 1);
  });

  test('routes abstraction to its scorer, per item', () async {
    // The fake returns the same map whatever it is asked, so the two items are
    // distinguished by the TERMS scoreItem sends, not by the reply.
    final fake = FakeSimilarityClient(similarities: {'ยานพาหนะ': 0.96});
    final outcome = await scoreItem(spec('abstraction-1'),
        transcript: 'ยานพาหนะ', similarity: fake);
    expect(outcome.score, 1);
    expect(fake.lastTerms, contains('ยานพาหนะ'));

    final second = FakeSimilarityClient(similarities: {'เครื่องมือวัด': 0.96});
    await scoreItem(spec('abstraction-2'),
        transcript: 'ยานพาหนะ', similarity: second);
    expect(second.lastTerms, contains('เครื่องมือวัด'));
    expect(second.lastTerms, isNot(contains('ยานพาหนะ')));
  });

  test('sends both the accepted terms and the stimulus words in one request',
      () async {
    // One request rather than two: two could straddle a backend restart and
    // mix similarities computed by different models.
    final fake = FakeSimilarityClient(similarities: {'ยานพาหนะ': 0.9});
    await scoreItem(spec('abstraction-1'),
        transcript: 'เป็นยานพาหนะ', similarity: fake);
    expect(fake.callCount, 1);
    expect(fake.lastTerms, containsAll(['ยานพาหนะ', 'รถไฟ', 'จักรยาน']));
  });

  test('splits the reply back into category and stimulus scores', () async {
    final fake = FakeSimilarityClient(similarities: {
      'ยานพาหนะ': 0.41,
      'รถไฟ': 0.74, // stimulus scores higher -> echo
    });
    final outcome = await scoreItem(spec('abstraction-1'),
        transcript: 'รถไฟกับจักรยาน', similarity: fake);
    expect(outcome.detail['reason'], 'stimulus-echo');
    expect(outcome.score, 0);
  });

  test('does not call the backend for an empty abstraction answer', () async {
    // Silence is scored 0 locally. The empty string embeds to a real vector
    // that scores ~0.45, so sending it would score the patient on the model's
    // opinion of nothing.
    final fake = FakeSimilarityClient(similarities: {'ยานพาหนะ': 0.99});
    final outcome =
        await scoreItem(spec('abstraction-1'), transcript: '', similarity: fake);
    expect(fake.callCount, 0);
    expect(outcome.score, 0);
    expect(outcome.detail['reason'], 'no-response');
  });

  test('throws rather than scoring abstraction with no client wired', () async {
    // Scoring 0 here would assert the patient failed an item the app never
    // actually evaluated.
    expect(
      () => scoreItem(spec('abstraction-1'), transcript: 'ยานพาหนะ'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('lets a similarity failure propagate to the Retry/Skip screen', () async {
    // Not caught and turned into a 0: an unreachable backend is not a patient
    // finding. The session controller turns this into the error phase.
    final fake = FakeSimilarityClient(
        throws: const SimilarityException('backend down'));
    expect(
      () => scoreItem(spec('abstraction-1'),
          transcript: 'ยานพาหนะ', similarity: fake),
      throwsA(isA<SimilarityException>()),
    );
  });

  test('routes orientation, using the reference date it is given', () async {
    final outcome = await scoreItem(
      spec('orientation'),
      transcript: 'ปี 2569',
      referenceDate: DateTime(2026, 8, 13),
    );
    expect(outcome.detail['year'], isTrue);
  });

  // Vigilance is the only scorer whose answer is not speech: the transcript is
  // always empty and the response arrives as tap offsets.
  test('routes vigilance, scoring taps rather than speech', () async {
    final taps = <int>[];
    final sequence = spec('vigilance').sequence!;
    for (var i = 0; i < sequence.length; i++) {
      if (sequence[i] == '1') taps.add(i * 1000 + 400);
    }

    final outcome = await scoreItem(spec('vigilance'), taps: taps);
    expect(outcome.score, 1);
    expect(outcome.detail['hits'], 11);
  });

  test('routes sentence repetition against its expected sentence', () async {
    final s = spec('sentence-repetition-1');
    final outcome = await scoreItem(s, transcript: s.expectedSentence!);
    expect(outcome.score, 1);
  });

  test('routes verbal fluency, counting segments', () async {
    final segments = [
      for (var i = 0; i < 11; i++)
        AsrSegment(start: i * 2.0, end: i * 2.0 + 1, text: 'ก$i'),
    ];
    final outcome = await scoreItem(spec('verbal-fluency'), segments: segments);
    expect(outcome.score, 1);
  });

  test('throws for a subtest with no scorer registered', () async {
    const rogue = SubtestSpec(
      id: 'not-a-subtest',
      section: 'x',
      instructionTh: 'x',
      instructionEn: 'x',
      maxScore: 1,
    );
    expect(() => scoreItem(rogue), throwsA(isA<ArgumentError>()));
  });
}

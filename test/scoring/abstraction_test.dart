import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/scoring/abstraction.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';

/// The similarity numbers in this file are REAL: measured on 2026-09-07 against
/// paraphrase-multilingual-MiniLM-L12-v2, the model backend/embeddings.py
/// loads. They are pasted in rather than computed so these tests stay offline
/// and deterministic — a unit test must not download 470 MB or depend on a
/// running backend.
///
/// That means they can go stale. If the model in embeddings.py changes, these
/// numbers describe the OLD model and the separations asserted here have to be
/// re-measured, not assumed. backend/tests/test_embeddings.py is the test that
/// checks the live model still ranks these answers the same way.
void main() {
  SubtestOutcome score(
    String id,
    String transcript, {
    required Map<String, double> category,
    required Map<String, double> stimulus,
  }) =>
      scoreAbstractionFromSimilarities(
        id,
        transcript,
        categoryScores: category,
        stimulusScores: stimulus,
      );

  group('the threshold rule', () {
    test('accepts a clear category answer', () {
      // "they are both vehicles" -> 0.805 category, 0.312 stimulus.
      final outcome = score('abstraction-1', 'they are both vehicles',
          category: {'vehicle': 0.805}, stimulus: {'train': 0.312});
      expect(outcome.score, 1);
      expect(outcome.detail['reason'], 'category-match');
    });

    test('rejects a concrete-feature answer', () {
      // "they both have wheels" -> 0.406. MoCA scores the abstract category,
      // not a shared physical feature.
      final outcome = score('abstraction-1', 'they both have wheels',
          category: {'vehicle': 0.406}, stimulus: {'train': 0.359});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'below-threshold');
    });

    test('scores on the best term, not the first one', () {
      final outcome = score('abstraction-1', 'a means of transport',
          category: {'vehicle': 0.31, 'transport': 0.855},
          stimulus: {'train': 0.503});
      expect(outcome.score, 1);
      expect(outcome.detail['best_term'], 'transport');
    });

    test('a value exactly on the threshold passes', () {
      final outcome = score('abstraction-1', 'borderline',
          category: {'vehicle': 0.55}, stimulus: {'train': 0.1});
      expect(outcome.score, 1);
    });
  });

  group('the stimulus-echo guard', () {
    // The failure the whole design exists to prevent. Scoring against the
    // stimulus words would rank this answer HIGHEST of all; the guard is what
    // makes measuring stimulus distance safe.
    test('rejects an answer that only repeats the two items back (EN)', () {
      // "a train and a bicycle" -> 0.598 category, but 0.703 stimulus. Note the
      // category score is ABOVE the 0.55 threshold: without the guard this
      // scores a point for restating the question.
      final outcome = score('abstraction-1', 'a train and a bicycle',
          category: {'vehicle': 0.598}, stimulus: {'train': 0.703});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'stimulus-echo');
    });

    test('rejects an answer that only repeats the two items back (TH)', () {
      // "รถไฟกับจักรยาน" -> 0.410 category, 0.737 stimulus.
      final outcome = score('abstraction-1', 'รถไฟกับจักรยาน',
          category: {'ยานพาหนะ': 0.410}, stimulus: {'รถไฟ': 0.737});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'stimulus-echo');
    });

    test('รฟ นาฬิกากับไม้บรรทัด is caught the same way', () {
      final outcome = score('abstraction-2', 'นาฬิกากับไม้บรรทัด',
          category: {'เครื่องมือวัด': 0.463}, stimulus: {'นาฬิกา': 0.916});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'stimulus-echo');
    });

    // The reason this scorer has no reject-list: a correct abstract answer is
    // allowed to mention a concrete detail too, and stripping the point for it
    // would take away something the patient earned. Do not "harden" this.
    test('accepts an abstract answer that also mentions a concrete detail', () {
      // "เป็นพาหนะที่มีล้อ" -> 0.716 category, 0.507 stimulus. Mentioning wheels
      // does not make it a stimulus echo.
      final outcome = score('abstraction-1', 'เป็นพาหนะที่มีล้อ',
          category: {'พาหนะ': 0.716}, stimulus: {'จักรยาน': 0.507});
      expect(outcome.score, 1);
    });

    test('the guard only ever removes a point, never grants one', () {
      // Below threshold AND far from the stimuli: still 0, and reported as a
      // threshold failure rather than an echo.
      final outcome = score('abstraction-1', 'they are made of metal',
          category: {'vehicle': 0.186}, stimulus: {'train': 0.168});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'below-threshold');
    });
  });

  group('no response', () {
    // The empty string does NOT embed to a zero vector — it scored 0.42-0.49
    // against the English accepted terms on 2026-09-07, above two of the
    // concrete wrong answers. Silence must never be scored on the model's
    // opinion of the empty string.
    test('scores 0 without consulting any similarity', () {
      final outcome = score('abstraction-1', '',
          category: const {}, stimulus: const {});
      expect(outcome.score, 0);
    });

    test('is recorded as a non-response, not a wrong answer', () {
      // The analysis page has to tell these apart: "no response" and "wrong
      // response" are different clinical findings.
      expect(score('abstraction-1', '', category: const {}, stimulus: const {})
          .detail['reason'], 'no-response');
    });

    test('whitespace-only is also a non-response', () {
      expect(score('abstraction-1', '   \n ',
              category: const {}, stimulus: const {}).detail['reason'],
          'no-response');
    });

    test('ignores similarities even if some were supplied', () {
      // Guards the ordering: the empty check must come BEFORE the threshold.
      final outcome = score('abstraction-1', '',
          category: {'vehicle': 0.99}, stimulus: {'train': 0.0});
      expect(outcome.score, 0);
      expect(outcome.detail['reason'], 'no-response');
    });
  });

  group('the stored audit trail', () {
    test('keeps every category similarity, not just the maximum', () {
      // "correct category, low similarity" is a scoring artefact and cannot be
      // told from a genuine miss without seeing all of them.
      final outcome = score('abstraction-1', 'x',
          category: {'vehicle': 0.2, 'transport': 0.4, 'travel': 0.1},
          stimulus: {'train': 0.05});
      expect(outcome.detail['category_similarities'],
          {'vehicle': 0.2, 'transport': 0.4, 'travel': 0.1});
    });

    test('keeps the stimulus similarities too', () {
      final outcome = score('abstraction-1', 'x',
          category: {'vehicle': 0.2}, stimulus: {'train': 0.05, 'bicycle': 0.9});
      expect(outcome.detail['stimulus_similarities'],
          {'train': 0.05, 'bicycle': 0.9});
    });

    test('records the threshold that was applied', () {
      // The threshold is unvalidated and will be re-chosen. A stored pass/fail
      // is uninterpretable without the number that produced it.
      final outcome = score('abstraction-1', 'x',
          category: {'vehicle': 0.2}, stimulus: {'train': 0.05});
      expect(outcome.detail['threshold'], kAbstractionSimilarityThreshold);
    });

    test('reports which accepted term matched, for checking real speech', () {
      final outcome = score('abstraction-1', 'ยานพาหนะ',
          category: {'ยานพาหนะ': 0.963}, stimulus: {'รถไฟ': 0.511});
      expect(outcome.detail['matched'], 'ยานพาหนะ');
    });

    test('reports no match when nothing was accepted', () {
      final outcome = score('abstraction-1', 'มีล้อ',
          category: {'ยานพาหนะ': 0.3}, stimulus: {'รถไฟ': 0.1});
      expect(outcome.detail['matched'], isNull);
      // best_term is still recorded even on a failure — it is what makes
      // "correct category, low similarity" visible on review.
      expect(outcome.detail['best_term'], 'ยานพาหนะ');
    });

    test('keeps the transcript verbatim', () {
      // Storing the raw transcript is the minimum needed to audit an
      // embedding score later, since failures are silent and plausible.
      expect(
          score('abstraction-1', 'ทั้งสองอย่างเป็นยานพาหนะครับ',
                  category: {'ยานพาหนะ': 0.9}, stimulus: {'รถไฟ': 0.4})
              .transcript,
          'ทั้งสองอย่างเป็นยานพาหนะครับ');
    });
  });

  group('the registered term lists', () {
    test('abstraction-1 is scored against the category, not the stimuli', () {
      expect(acceptedTermsFor('abstraction-1', language: Language.en),
          contains('vehicle'));
      expect(stimulusWordsFor('abstraction-1', language: Language.en),
          ['train', 'bicycle']);
    });

    test('the English list carries verb forms, mirroring the Thai one', () {
      // Thai has both the category noun (ยานพาหนะ) and the travel verb
      // (เดินทาง). Without the English equivalents, the correct answer "both
      // are used for getting around" scored 0.193 — below two wrong answers.
      final en = acceptedTermsFor('abstraction-1', language: Language.en);
      expect(en, contains('travel'));
      expect(en, contains('getting around'));
    });

    test('defaults to Thai when no language is passed', () {
      AppLanguage.current = Language.th;
      expect(acceptedTermsFor('abstraction-1'), contains('ยานพาหนะ'));
    });

    // A typo in a subtest id must not silently score every patient zero on an
    // item that was never really administered, and look like a clinical finding.
    test('throws on an unknown item rather than scoring it wrong', () {
      expect(() => acceptedTermsFor('abstraction-9', language: Language.en),
          throwsA(isA<ArgumentError>()));
      expect(() => stimulusWordsFor('abstraction-9', language: Language.en),
          throwsA(isA<ArgumentError>()));
    });

    test('does not let one item answer score the other', () {
      // The term lists are disjoint, so "เครื่องมือวัด" cannot be near any
      // abstraction-1 term. Asserted on the lists rather than on similarities,
      // since that is what actually guarantees it.
      final one = acceptedTermsFor('abstraction-1', language: Language.th);
      final two = acceptedTermsFor('abstraction-2', language: Language.th);
      expect(one.toSet().intersection(two.toSet()), isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/analysis/domain_analysis.dart';
import 'package:moca_main/moca/activities.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';
import 'package:moca_main/scoring/vigilance.dart';

/// The per-domain analysis.
///
/// The first group is the one that matters most. Everything else on this page
/// is description, and description is allowed to be wrong in a way a status is
/// not — a status is what a patient will remember and repeat.
void main() {
  setUp(() => AppLanguage.current = Language.en);
  tearDown(() => AppLanguage.current = Language.th);

  SessionRecord record({
    int larkScore = 0,
    int clockScore = 0,
    int animalScore = 0,
    int attentionScore = 0,
    int reorderScore = 0,
    Map<String, SubtestOutcome> voiceOutcomes = const {},
    TraceLog? trace,
  }) =>
      SessionRecord(
        id: 'test',
        startedAt: DateTime(2026, 9, 7),
        larkScore: larkScore,
        clockScore: clockScore,
        animalScore: animalScore,
        attentionScore: attentionScore,
        reorderScore: reorderScore,
        voiceOutcomes: voiceOutcomes,
        trace: trace,
      );

  SubtestOutcome outcome(
    String id, {
    required int score,
    int maxScore = 1,
    String transcript = '',
    Map<String, dynamic> detail = const {},
  }) =>
      SubtestOutcome(
        subtestId: id,
        score: score,
        maxScore: maxScore,
        transcript: transcript,
        detail: detail,
      );

  DomainAnalysis domain(SessionRecord r, String id) =>
      analyseSession(r).firstWhere((d) => d.id == id);

  List<String> texts(DomainAnalysis d) =>
      [for (final o in d.observations) o.text];

  group('the status comes from the points and from nothing else', () {
    test('full marks stay full marks however bad the measurements look', () {
      // Every measurement here is as alarming as the stored data can make it:
      // a barely-passing similarity, misses, a near-threshold abstraction. The
      // patient still earned every point, so the status is still `full`. If
      // this test ever fails, a measurement has been allowed to downgrade
      // someone with no norms behind it.
      final r = record(
        voiceOutcomes: {
          'sentence-repetition-1': outcome('sentence-repetition-1',
              score: 1, detail: {'similarity': 0.901, 'threshold': 0.9}),
          'sentence-repetition-2': outcome('sentence-repetition-2',
              score: 1, detail: {'similarity': 0.9, 'threshold': 0.9}),
          'verbal-fluency': outcome('verbal-fluency', score: 1, detail: {
            'distinctCount': 11,
            'threshold': 11,
            'rejectedWrongLetter': ['banana', 'orange'],
          }),
        },
      );
      expect(domain(r, 'language').status, DomainStatus.full);
    });

    test('partial when some points were earned', () {
      expect(domain(record(larkScore: 1, clockScore: 1), 'visuospatial-executive').status,
          DomainStatus.partial);
    });

    test('zero points is `none`, which is a finding about a real attempt', () {
      expect(domain(record(animalScore: 0), 'naming').status, DomainStatus.none);
    });

    test('a domain with nothing administered gets no class at all', () {
      // The same refusal `SessionTotal.category` makes for a partial session.
      // "Not administered" is not a worse grade than "no points"; it is the
      // absence of a grade.
      final d = domain(record(), 'language');
      expect(d.status, DomainStatus.notAdministered);
      expect(d.maxScore, 0);
    });

    test('a skipped subtest leaves both sides of the domain, not just one', () {
      final r = record(voiceOutcomes: {
        'abstraction-1': outcome('abstraction-1', score: 1),
        'abstraction-2': SubtestOutcome.skippedFor('abstraction-2'),
      });
      final d = domain(r, 'abstraction');
      // Counting the skipped item as a zero would read 1/2 — a manufactured
      // deficit for a subtest the patient was never asked.
      expect(d.score, 1);
      expect(d.maxScore, 1);
      expect(d.status, DomainStatus.full);
      expect(d.skipped, isNotEmpty);
    });

    test('serial 7s always counts, because that page cannot be skipped', () {
      final d = domain(record(attentionScore: 3), 'attention');
      expect(d.score, 3);
      expect(d.maxScore, 3);
    });
  });

  group('domain wiring', () {
    test('every domain links to an activity domain that exists', () {
      for (final d in analyseSession(record())) {
        expect(domainById(d.activityDomainId), isNotNull, reason: d.id);
      }
    });

    test('domain ids are unique and cover the MoCA form', () {
      final ids = analyseSession(record()).map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(
          ids,
          containsAll([
            'visuospatial-executive',
            'naming',
            'attention',
            'language',
            'abstraction',
            'delayed-recall',
            'orientation',
          ]));
    });

    test('every voice subtest is accounted for by exactly one domain', () {
      // A subtest that belongs to no domain would vanish from this page while
      // still counting toward the total, which is worse than not having the
      // page: the numbers would not add up and nothing would say why.
      final r = record(voiceOutcomes: {
        for (final spec in kVoiceSubtests)
          spec.id: outcome(spec.id, score: spec.maxScore, maxScore: spec.maxScore),
      });
      final domainMax = analyseSession(r).fold<int>(0, (sum, d) => sum + d.maxScore);
      final expected = 1 + 3 + 3 + 3 + 5 + // the five original subtests
          kVoiceSubtests.fold<int>(0, (sum, s) => sum + s.maxScore);
      expect(domainMax, expected);
    });
  });

  group('clock — the score already names the failure point', () {
    test('0 says the outline failed', () {
      expect(texts(domain(record(clockScore: 0), 'visuospatial-executive')).join(),
          contains('outline was not completed'));
    });

    test('2 says the hands failed and why that matters', () {
      final t = texts(domain(record(clockScore: 2), 'visuospatial-executive')).join();
      expect(t, contains('hands were not set'));
      expect(t, contains('executive-loaded'));
    });

    test('a partial clock carries the cumulative-scoring caveat', () {
      final d = domain(record(clockScore: 2), 'visuospatial-executive');
      expect(
        d.observations.where((o) => o.tone == ObservationTone.caution).map((o) => o.text).join(),
        contains('cumulative'),
      );
    });

    test('a full clock does not', () {
      final d = domain(record(clockScore: 3), 'visuospatial-executive');
      expect(d.observations.where((o) => o.tone == ObservationTone.caution), isEmpty);
    });
  });

  group('what is not measured says so', () {
    test('the trail records no timing', () {
      final d = domain(record(), 'visuospatial-executive');
      expect(
        d.observations.where((o) => o.tone == ObservationTone.notCaptured).map((o) => o.text).join(),
        contains('Trail making'),
      );
    });

    test('naming says so for a session recorded before the keyboard existed', () {
      final d = domain(record(animalScore: 3), 'naming');
      expect(d.observations.single.tone, ObservationTone.notCaptured);
    });

    test('serial 7s records answers but not per-item timing', () {
      final d = domain(record(attentionScore: 1), 'attention');
      expect(
        d.observations.where((o) => o.tone == ObservationTone.notCaptured).map((o) => o.text).join(),
        contains('Serial 7s'),
      );
    });
  });

  group('digit span error shapes', () {
    SessionRecord spans({required String forward, required String backward}) => record(
          voiceOutcomes: {
            'digit-span-forward': outcome('digit-span-forward',
                score: forward == '21854' ? 1 : 0,
                detail: {'spoken': forward, 'expected': '21854'}),
            'digit-span-backward': outcome('digit-span-backward',
                score: backward == '247' ? 1 : 0,
                detail: {'spoken': backward, 'expected': '247'}),
          },
        );

    test('all digits present but reordered is a transposition', () {
      final t = texts(domain(spans(forward: '21854', backward: '274'), 'attention')).join();
      expect(t, contains('Every digit is present but transposed'));
      // The reading that makes backward span worth administering at all.
      expect(t, contains('manipulation impaired'));
    });

    test('missing trailing digits is a span limit, not a transposition', () {
      final t = texts(domain(spans(forward: '218', backward: '247'), 'attention')).join();
      expect(t, contains('final digits are missing'));
    });

    test('extra digits are named as such', () {
      final t = texts(domain(spans(forward: '218547', backward: '247'), 'attention')).join();
      expect(t, contains('Extra digits'));
    });

    test('an empty transcript is flagged as a recogniser limit, not an answer', () {
      final d = domain(spans(forward: '', backward: '247'), 'attention');
      final cautions = d.observations.where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(), contains('speech recogniser'));
    });

    test('forward intact and backward failed points at executive load', () {
      final t = texts(domain(spans(forward: '21854', backward: '274'), 'attention')).join();
      expect(t, contains('Forward intact, backward failed'));
    });

    test('both failed is read as span, before any executive interpretation', () {
      final t = texts(domain(spans(forward: '218', backward: '274'), 'attention')).join();
      expect(t, contains('basic attention span'));
    });
  });

  group('vigilance', () {
    /// Taps every target except those at [missing], each 300 ms after onset.
    SubtestOutcome vigilanceWith({List<int> missing = const []}) {
      final digits = kVigilanceSequence.split('');
      final taps = <int>[
        for (var i = 0; i < digits.length; i++)
          if (digits[i] == '1' && !missing.contains(i)) i * 1000 + 300,
      ];
      return scoreVigilance(taps,
          sequence: kVigilanceSequence, target: '1', intervalMs: 1000);
    }

    test('misses and false taps are reported separately, not summed', () {
      final r = record(voiceOutcomes: {'vigilance': vigilanceWith(missing: [2, 6])});
      final t = texts(domain(r, 'attention')).join();
      expect(t, contains('2 missed targets, 0 false taps'));
      expect(t, contains('Misses only'));
    });

    test('errors all in the last third are named as a decrement', () {
      // 29 digits, so the last third begins at index 19.33. Targets 20 and 22.
      final r = record(voiceOutcomes: {'vigilance': vigilanceWith(missing: [20, 22])});
      expect(texts(domain(r, 'attention')).join(), contains('last third'));
    });

    test('errors spread across the sequence are not', () {
      final r = record(voiceOutcomes: {'vigilance': vigilanceWith(missing: [2, 26])});
      expect(texts(domain(r, 'attention')).join(), isNot(contains('last third')));
    });

    test('reaction times are reported as a range, never as a band', () {
      final r = record(voiceOutcomes: {'vigilance': vigilanceWith()});
      final t = texts(domain(r, 'attention')).join();
      expect(t, contains('averaged 300 ms'));
      expect(t, isNot(contains('percentile')));
    });
  });

  group('sentence repetition', () {
    test('the similarity is shown, not just pass or fail', () {
      final r = record(voiceOutcomes: {
        'sentence-repetition-1': outcome('sentence-repetition-1',
            score: 1, detail: {'similarity': 0.94, 'threshold': 0.9}),
      });
      expect(texts(domain(r, 'language')).join(), contains('0.94'));
    });

    test('a near miss is called a threshold artefact, not a patient finding', () {
      final r = record(voiceOutcomes: {
        'sentence-repetition-1': outcome('sentence-repetition-1',
            score: 0, detail: {'similarity': 0.88, 'threshold': 0.9}),
      });
      final cautions = domain(r, 'language')
          .observations
          .where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(), contains('artefact of the threshold'));
    });

    test('a genuine miss is not', () {
      final r = record(voiceOutcomes: {
        'sentence-repetition-1': outcome('sentence-repetition-1',
            score: 0, detail: {'similarity': 0.4, 'threshold': 0.9}),
      });
      expect(
          domain(r, 'language')
              .observations
              .where((o) => o.tone == ObservationTone.caution),
          isEmpty);
    });
  });

  group('verbal fluency', () {
    test('words that broke the letter rule are listed', () {
      final r = record(voiceOutcomes: {
        'verbal-fluency': outcome('verbal-fluency', score: 0, transcript: 'a b c', detail: {
          'distinctCount': 3,
          'threshold': 11,
          'rejectedWrongLetter': ['banana'],
        }),
      });
      expect(texts(domain(r, 'language')).join(), contains('did not start with the target letter'));
    });

    test('a long spaceless Thai transcript is flagged as a scoring artefact', () {
      // The known limit already in the README: no spaces means one token.
      final r = record(voiceOutcomes: {
        'verbal-fluency': outcome('verbal-fluency',
            score: 0,
            transcript: 'ก' * 60,
            detail: {'distinctCount': 1, 'threshold': 11}),
      });
      final cautions = domain(r, 'language')
          .observations
          .where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(), contains('no spaces'));
    });

    test('repeated words are surfaced, since the score counts only distinct ones', () {
      final r = record(voiceOutcomes: {
        'verbal-fluency': outcome('verbal-fluency',
            score: 0,
            transcript: 'fish fish fowl',
            detail: {'distinctCount': 2, 'threshold': 11}),
      });
      expect(texts(domain(r, 'language')).join(), contains('1 repeated word'));
    });
  });

  group('abstraction', () {
    test('no response is distinguished from a wrong response', () {
      final r = record(voiceOutcomes: {
        'abstraction-1':
            outcome('abstraction-1', score: 0, detail: {'reason': 'no-response'}),
      });
      expect(texts(domain(r, 'abstraction')).join(), contains('no answer was given'));
    });

    test('restating the stimuli is named as such', () {
      final r = record(voiceOutcomes: {
        'abstraction-1': outcome('abstraction-1',
            score: 0,
            transcript: 'a train and a bicycle',
            detail: {
              'best_category_similarity': 0.41,
              'best_stimulus_similarity': 0.74,
              'threshold': 0.55,
            }),
      });
      expect(texts(domain(r, 'abstraction')).join(), contains('restating the two things'));
    });

    test('a concrete answer is the failure the item exists to catch', () {
      final r = record(voiceOutcomes: {
        'abstraction-1': outcome('abstraction-1',
            score: 0,
            transcript: 'they both have wheels',
            detail: {
              'best_category_similarity': 0.30,
              'best_stimulus_similarity': 0.20,
              'threshold': 0.55,
            }),
      });
      expect(texts(domain(r, 'abstraction')).join(), contains('property matching'));
    });

    test('a correct category just under the line is a threshold artefact', () {
      final r = record(voiceOutcomes: {
        'abstraction-1': outcome('abstraction-1',
            score: 0,
            transcript: 'both are used for getting around',
            detail: {
              'best_category_similarity': 0.52,
              'best_stimulus_similarity': 0.20,
              'threshold': 0.55,
            }),
      });
      final cautions = domain(r, 'abstraction')
          .observations
          .where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(), contains('never been validated'));
    });
  });

  group('delayed recall', () {
    TraceLog recallTrace(List<String> recalled, List<String> target) {
      final log = TraceLog(startedAt: DateTime(2026, 9, 7));
      log.add('delayed-recall', TraceEventType.scored, data: {
        'recalled': recalled,
        'target': target,
        'maxScore': 5,
      });
      return log;
    }

    const target = ['a', 'b', 'c', 'd', 'e'];

    test('without the arrangement, it says so rather than guessing', () {
      final d = domain(record(reorderScore: 2), 'delayed-recall');
      expect(d.observations.single.tone, ObservationTone.notCaptured);
    });

    test('recognition is reported separately from position', () {
      final r = record(
        reorderScore: 1,
        trace: recallTrace(['a', 'c', 'b', 'd', 'e'], target),
      );
      expect(texts(domain(r, 'delayed-recall')).join(),
          contains('Recognised 5 of 5 pictures'));
    });

    test('all five recognised with only adjacent swaps is said to be partial order', () {
      final r = record(
        reorderScore: 3,
        trace: recallTrace(['b', 'a', 'c', 'e', 'd'], target),
      );
      expect(texts(domain(r, 'delayed-recall')).join(), contains('adjacent swaps'));
    });

    test('wider displacement is not called an adjacent swap', () {
      final r = record(
        reorderScore: 1,
        trace: recallTrace(['e', 'b', 'c', 'd', 'a'], target),
      );
      final t = texts(domain(r, 'delayed-recall')).join();
      expect(t, contains('wider than adjacent swaps'));
    });

    test('a recognition failure is separated from a sequencing one', () {
      final r = record(
        reorderScore: 2,
        trace: recallTrace(['a', 'b', 'x', 'y', 'e'], target),
      );
      expect(texts(domain(r, 'delayed-recall')).join(),
          contains('encoding or storage, not sequencing'));
    });
  });

  group('orientation', () {
    SessionRecord oriented(Map<String, bool> fields) => record(voiceOutcomes: {
          'orientation': outcome('orientation',
              score: fields.values.where((v) => v).length,
              maxScore: 6,
              detail: {...fields}),
        });

    const allRight = {
      'day': true, 'date': true, 'month': true,
      'year': true, 'place': true, 'province': true,
    };

    test('names which items failed, since the field matters more than the count', () {
      final r = oriented({...allRight, 'month': false});
      expect(texts(domain(r, 'orientation')).join(), contains('Incorrect: month'));
    });

    test('a wrong date alone is called weak evidence', () {
      final r = oriented({...allRight, 'date': false});
      expect(texts(domain(r, 'orientation')).join(), contains('weak evidence'));
    });

    test('a wrong place carries the compile-time-constant warning', () {
      // Until the settings screen exists, a place failure at a second site is
      // an app defect and must not be presented as a patient finding.
      final r = oriented({...allRight, 'place': false});
      final cautions = domain(r, 'orientation')
          .observations
          .where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(), contains('compile-time constants'));
    });

    test('a clean orientation carries no caution', () {
      final d = domain(oriented(allRight), 'orientation');
      expect(d.observations.where((o) => o.tone == ObservationTone.caution), isEmpty);
    });
  });

  group('naming, from the in-app keyboard', () {
    /// One naming item, laid out on a millisecond timeline.
    ///
    /// [gaps] are the intervals between successive keystrokes, so a test can
    /// describe "fast typing after a long search" without arithmetic.
    void addItem(
      TraceLog log, {
      required int index,
      required String target,
      required String answer,
      required bool correct,
      required int shownAtMs,
      required int firstKeyAfterMs,
      required List<int> gaps,
      int deletes = 0,
    }) {
      final start = DateTime(2026, 9, 7);
      var at = shownAtMs;
      log.add('naming', TraceEventType.itemShown,
          data: {'itemIndex': index, 'target': target},
          at: start.add(Duration(milliseconds: at)));
      at += firstKeyAfterMs;
      for (var i = 0; i < answer.length; i++) {
        if (i > 0) at += gaps[(i - 1) % gaps.length];
        log.add('naming', TraceEventType.keyPressed,
            data: {'itemIndex': index, 'key': answer[i], 'length': i + 1},
            at: start.add(Duration(milliseconds: at)));
      }
      for (var i = 0; i < deletes; i++) {
        at += 400;
        log.add('naming', TraceEventType.keyDeleted,
            data: {'itemIndex': index, 'length': answer.length},
            at: start.add(Duration(milliseconds: at)));
      }
      at += 500;
      log.add('naming', TraceEventType.submitted,
          data: {
            'itemIndex': index,
            'answer': answer,
            'target': target,
            'correct': correct,
          },
          at: start.add(Duration(milliseconds: at)));
    }

    TraceLog log() => TraceLog(startedAt: DateTime(2026, 9, 7));

    test('reports time to first keypress, the word-finding proxy', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'lion',
          answer: 'lion',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 2400,
          gaps: [500]);
      expect(texts(domain(record(animalScore: 3, trace: l), 'naming')).join(),
          contains('started typing 2.4 s after the picture appeared'));
    });

    test('a long search then fluent typing is retrieval, not motor', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'lion',
          answer: 'lion',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 9000,
          gaps: [400]);
      addItem(l,
          index: 1,
          target: 'camel',
          answer: 'camel',
          correct: true,
          shownAtMs: 20000,
          firstKeyAfterMs: 1000,
          gaps: [400]);
      expect(texts(domain(record(animalScore: 3, trace: l), 'naming')).join(),
          contains('hard to retrieve, not hard to type'));
    });

    test('a mid-word stall is measured against the patient, not a norm', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'camel',
          answer: 'camel',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 1000,
          // Three fast gaps then one long one.
          gaps: [300, 300, 5000, 300]);
      final t = texts(domain(record(animalScore: 3, trace: l), 'naming')).join();
      expect(t, contains('paused 5.0 s mid-word'));
      // Stated against their own baseline, never as a band or a percentile.
      expect(t, contains("this patient's own typical"));
      expect(t, isNot(contains('percentile')));
    });

    test('corrections are counted', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'camel',
          answer: 'camel',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 800,
          gaps: [300],
          deletes: 2);
      expect(texts(domain(record(animalScore: 3, trace: l), 'naming')).join(),
          contains('2 corrections while typing'));
    });

    test('a near-miss spelling is flagged as a typo, and still scored wrong',
        () {
      // The plan's example: "camle" for camel is a typing error, not anomia.
      // It is a caution because it is a statement about the scoring — and it
      // is deliberately not acted on. Whether it should still cost the point
      // is a clinical decision, not one this page makes quietly.
      final l = log();
      addItem(l,
          index: 0,
          target: 'camel',
          answer: 'camle',
          correct: false,
          shownAtMs: 0,
          firstKeyAfterMs: 900,
          gaps: [300]);
      final d = domain(record(animalScore: 2, trace: l), 'naming');
      expect(
        d.observations.where((o) => o.tone == ObservationTone.caution).map((o) => o.text).join(),
        contains('typing error rather than a naming failure'),
      );
      expect(d.score, 2, reason: 'the score is untouched by the observation');
    });

    test('a genuinely different word is not called a typo', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'camel',
          answer: 'horse',
          correct: false,
          shownAtMs: 0,
          firstKeyAfterMs: 900,
          gaps: [300]);
      expect(
          domain(record(animalScore: 2, trace: l), 'naming')
              .observations
              .where((o) => o.tone == ObservationTone.caution),
          isEmpty);
    });

    test('no answer at all is distinguished from a wrong one', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'camel',
          answer: '',
          correct: false,
          shownAtMs: 0,
          firstKeyAfterMs: 0,
          gaps: [300]);
      expect(texts(domain(record(animalScore: 2, trace: l), 'naming')).join(),
          contains('no answer given'));
    });

    test('names which keyboard was used', () {
      final l = log();
      l.add('naming', TraceEventType.itemShown,
          data: {'itemIndex': 0, 'target': 'lion', 'layout': 'standard'});
      addItem(l,
          index: 0,
          target: 'lion',
          answer: 'lion',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 900,
          gaps: [400]);
      expect(texts(domain(record(animalScore: 3, trace: l), 'naming')).join(),
          contains('standard layout'));
    });

    test('refuses a typing baseline when the layout changed mid-subtest', () {
      // A key that moved is not the same measurement. Averaging across the
      // change would produce a confident baseline built from two tasks.
      final l = log();
      l.add('naming', TraceEventType.itemShown,
          data: {'itemIndex': 0, 'target': 'lion', 'layout': 'alphabetical'});
      addItem(l,
          index: 0,
          target: 'lion',
          answer: 'lion',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 900,
          gaps: [400]);
      l.add('naming', TraceEventType.itemShown,
          data: {'itemIndex': 1, 'target': 'camel', 'layout': 'standard'});
      addItem(l,
          index: 1,
          target: 'camel',
          answer: 'camel',
          correct: true,
          shownAtMs: 20000,
          firstKeyAfterMs: 900,
          gaps: [1200]);

      final d = domain(record(animalScore: 3, trace: l), 'naming');
      final all = texts(d).join();
      expect(
        d.observations.where((o) => o.tone == ObservationTone.caution).map((o) => o.text).join(),
        contains('not the same measurement'),
      );
      // And the baseline sentence is withheld entirely, not shown with a
      // caveat next to it.
      expect(all, isNot(contains('typing pace was')));
    });

    test('the typing baseline is the patient, and says so', () {
      final l = log();
      addItem(l,
          index: 0,
          target: 'lion',
          answer: 'lion',
          correct: true,
          shownAtMs: 0,
          firstKeyAfterMs: 900,
          gaps: [400]);
      final t = texts(domain(record(animalScore: 3, trace: l), 'naming')).join();
      expect(t, contains('only to compare them against themselves'));
      expect(t, contains('varies far too much with age and device familiarity'));
    });
  });

  group('the trace adds what an outcome cannot carry', () {
    test('retries are surfaced — same score, different administration', () {
      final log = TraceLog(startedAt: DateTime(2026, 9, 7));
      log.add('orientation', TraceEventType.retried);
      log.add('orientation', TraceEventType.retried);
      final r = record(trace: log, voiceOutcomes: {
        'orientation':
            outcome('orientation', score: 6, maxScore: 6, detail: const {}),
      });
      expect(texts(domain(r, 'orientation')).join(), contains('re-administered 2 times'));
    });

    test('a backend failure during a subtest is flagged against its score', () {
      final log = TraceLog(startedAt: DateTime(2026, 9, 7));
      log.add('verbal-fluency', TraceEventType.failed, data: {'where': 'begin'});
      final r = record(trace: log, voiceOutcomes: {
        'verbal-fluency': outcome('verbal-fluency',
            score: 0, detail: {'distinctCount': 0, 'threshold': 11}),
      });
      final cautions =
          domain(r, 'language').observations.where((o) => o.tone == ObservationTone.caution);
      expect(cautions.map((o) => o.text).join(),
          contains('may reflect the system rather than the patient'));
    });
  });

  group('framing', () {
    test('states that the level comes from the points alone', () {
      expect(analysisFraming.join(), contains('from nothing else'));
    });

    test('states that the detail changes no level and has no norms', () {
      final joined = analysisFraming.join();
      expect(joined, contains('not a percentile'));
      expect(joined, contains('does not change the level'));
    });

    test('says the app is a screening tool, in both languages', () {
      expect(analysisFraming.join(), contains('not a diagnosis'));
      AppLanguage.current = Language.th;
      expect(analysisFraming.join(), contains('ไม่ใช่การวินิจฉัยโรค'));
      expect(analysisFraming, hasLength(4));
    });
  });
}

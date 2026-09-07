import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/session_controller.dart';
import 'package:moca_main/moca/similarity_client.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';

/// What the session controller writes into the trace.
///
/// These are the events every measurement in the improvement plan is computed
/// from, so a missing one is a measurement that silently becomes impossible
/// later rather than a test that fails loudly now.
void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  late TraceLog trace;

  setUp(() => trace = TraceLog(startedAt: DateTime.now()));

  SubtestSessionController build(
    SubtestSpec s, {
    AsrClient? asr,
    SimilarityClient? similarity,
    TraceLog? log,
    Set<String> missingAssets = const {},
  }) =>
      SubtestSessionController(
        spec: s,
        asr: asr ?? FakeAsrClient(text: 'สองหนึ่งแปดห้าสี่'),
        recorder: FakeVoiceRecorder(),
        playback: FakeAudioPlayback(),
        similarity: similarity ?? FakeSimilarityClient(),
        trace: log ?? trace,
        assetExists: (path) async => !missingAssets.contains(path),
      );

  List<String> typesFor(String subtestId) =>
      trace.forSubtest(subtestId).map((e) => e.type).toList();

  group('a voice subtest', () {
    test('records the stimulus boundaries and the recording window', () async {
      // The gap between stimulusEnd and the patient speaking is the initiation
      // latency several subtests want.
      final controller = build(spec('digit-span-forward'));
      await controller.begin();
      await controller.finishRecording();

      expect(
        typesFor('digit-span-forward'),
        containsAllInOrder([
          TraceEventType.started,
          TraceEventType.stimulusStart,
          TraceEventType.stimulusEnd,
          TraceEventType.recordingStart,
          TraceEventType.recordingEnd,
          TraceEventType.scored,
        ]),
      );
    });

    test('records the score alongside the event', () async {
      // So a trace is self-contained for review even read on its own.
      final controller = build(spec('digit-span-forward'));
      await controller.begin();
      await controller.finishRecording();

      final scored = trace
          .forSubtest('digit-span-forward')
          .lastWhere((e) => e.type == TraceEventType.scored);
      expect(scored.data['score'], 1);
      expect(scored.data['maxScore'], 1);
    });

    test('a subtest with no stimulus records no stimulus events', () async {
      // Abstraction has no stimulus by design; inventing a boundary would put
      // a latency origin in the trace that never happened.
      final controller = build(spec('abstraction-1'));
      await controller.begin();
      expect(typesFor('abstraction-1'),
          isNot(contains(TraceEventType.stimulusStart)));
      expect(typesFor('abstraction-1'), contains(TraceEventType.recordingStart));
    });
  });

  // The digit sequence runs in real time — a 1 s lead-in then 29 digits at 1 s
  // each — so these use testWidgets and pumped fake time, the way the existing
  // tap-mode tests in session_controller_test.dart do. A plain `test` here
  // simply times out.
  group('vigilance', () {
    testWidgets('records every digit with its index and whether it was a target',
        (tester) async {
      // Error position across the 29 digits — the vigilance-decrement measure —
      // is recoverable only if each digit carries its index.
      final controller = build(spec('vigilance'));
      final begun = controller.begin();
      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      final digits = trace
          .forSubtest('vigilance')
          .where((e) => e.type == TraceEventType.digitPlayed)
          .toList();
      expect(digits.length, kVigilanceSequence.length);
      expect(digits.first.data['index'], 0);
      expect(digits.last.data['index'], kVigilanceSequence.length - 1);
      // 11 of the 29 are targets, straight from the Thai MoCA-Basic form.
      expect(
          digits.where((e) => e.data['isTarget'] == true).length, 11);
    });

    testWidgets('marks the digit onsets as scheduled, not measured',
        (tester) async {
      // They are computed from the sequence and interval, because the player
      // reports only the start of the whole run. The trace says so rather than
      // letting a later reader assume they were observed.
      final controller = build(spec('vigilance'));
      final begun = controller.begin();
      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      final digit = trace
          .forSubtest('vigilance')
          .firstWhere((e) => e.type == TraceEventType.digitPlayed);
      expect(digit.data['scheduled'], isTrue);
      expect(digit.data['offsetMs'], 0);
    });

    testWidgets('records every tap, including ones the scorer collapses',
        (tester) async {
      // The scorer counts two taps inside one window as a single event. Both
      // are kept here: latency variance is recomputed from raw taps later, and
      // a collapsed tap is invisible to it.
      final controller = build(spec('vigilance'));
      final begun = controller.begin();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.phase, SessionPhase.tapping);

      controller.recordTap();
      controller.recordTap();

      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      final taps = trace
          .forSubtest('vigilance')
          .where((e) => e.type == TraceEventType.tap)
          .toList();
      expect(taps.length, 2);
      // Each carries its offset from the sequence start, which is what every
      // latency measure is computed against.
      expect(taps.first.data['sinceSequenceStartMs'], isA<int>());
    });

    testWidgets('does not record a tap made outside the tapping phase',
        (tester) async {
      // A press during the lead-in is not an answer to any digit, so it must
      // not become one in the trace either.
      final controller = build(spec('vigilance'));
      controller.recordTap();
      final begun = controller.begin();
      controller.recordTap();

      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      expect(
        trace.forSubtest('vigilance').where((e) => e.type == TraceEventType.tap),
        isEmpty,
      );
    });
  });

  group('what went wrong is recorded too', () {
    test('a backend failure is traced, so a 0 from an outage is visible',
        () async {
      // Without this, a low total from a backend outage is indistinguishable
      // on review from one the patient earned.
      final controller = build(spec('digit-span-forward'),
          asr: FakeAsrClient(throws: const AsrException('offline')));
      await controller.begin();
      await controller.finishRecording();

      final failed = trace
          .forSubtest('digit-span-forward')
          .where((e) => e.type == TraceEventType.failed);
      expect(failed, isNotEmpty);
      expect(failed.first.data['error'], contains('offline'));
    });

    test('a retry is recorded', () async {
      // A subtest retried three times is not the same as one answered first
      // time, even at the same score.
      final controller = build(spec('abstraction-1'));
      await controller.begin();
      controller.retry();
      expect(typesFor('abstraction-1'), contains(TraceEventType.retried));
    });

    test('a skip is recorded as skipped, never as a score of zero', () async {
      final controller = build(spec('abstraction-1'));
      controller.skip();
      final types = typesFor('abstraction-1');
      expect(types, contains(TraceEventType.skipped));
      expect(types, isNot(contains(TraceEventType.scored)));
    });

    test('a missing stimulus traces a skip, not a failure', () async {
      // The subtest was never administered. Recording it as a failure would
      // assert the patient could not do it.
      final s = spec('sentence-repetition-1');
      final controller =
          build(s, missingAssets: {s.stimulusAssetForLanguage!});
      await controller.begin();
      expect(typesFor(s.id), contains(TraceEventType.skipped));
    });
  });

  test('tracing is optional and never blocks a subtest', () async {
    // Under `flutter test`, and on any page reached without starting a
    // session, there is no trace. That must not stop an assessment.
    final controller = SubtestSessionController(
      spec: spec('abstraction-1'),
      asr: FakeAsrClient(text: 'ยานพาหนะ'),
      recorder: FakeVoiceRecorder(),
      playback: FakeAudioPlayback(),
      similarity: FakeSimilarityClient(similarities: const {'ยานพาหนะ': 0.96}),
      trace: null,
      assetExists: (_) async => true,
    );
    await controller.begin();
    await controller.finishRecording();
    expect(controller.outcome!.score, 1);
  });
}

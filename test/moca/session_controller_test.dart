import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';
import 'package:moca_main/moca/session_controller.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  // Assets "exist" unless a test says otherwise, so asset resolution under
  // flutter test can never decide the outcome of a test about something else.
  SubtestSessionController build(
    SubtestSpec s, {
    AsrClient? asr,
    VoiceRecorder? recorder,
    AudioPlayback? playback,
    Set<String> missingAssets = const {},
  }) =>
      SubtestSessionController(
        spec: s,
        asr: asr ?? FakeAsrClient(text: 'สองหนึ่งแปดห้าสี่'),
        recorder: recorder ?? FakeVoiceRecorder(),
        playback: playback ?? FakeAudioPlayback(),
        assetExists: (path) async => !missingAssets.contains(path),
      );

  test('starts in the instruction phase', () {
    expect(build(spec('abstraction-1')).phase, SessionPhase.instruction);
  });

  // THE invariant. If the microphone opens while the stimulus is still
  // playing, the recognizer transcribes the app's own prompt and the subtest
  // appears to pass while measuring nothing — a failure that looks exactly
  // like success. Asserting literal call order is the only way to catch it.
  test('never opens the microphone before playback has finished', () async {
    final order = <String>[];
    final playback = _RecordingPlayback(order);
    final recorder = _RecordingRecorder(order);

    final controller =
        build(spec('digit-span-forward'), playback: playback, recorder: recorder);
    await controller.begin();

    expect(order, [
      'play-start:assets/moca/audio/digits-forward.wav',
      'play-complete:assets/moca/audio/digits-forward.wav',
      'start',
    ]);
  });

  test('a subtest with no stimulus opens the microphone directly', () async {
    final playback = FakeAudioPlayback();
    final controller = build(spec('abstraction-1'), playback: playback);

    await controller.begin();

    expect(playback.calls.where((c) => c.startsWith('play:')), isEmpty);
    expect(controller.phase, SessionPhase.recording);
  });

  // The safety net. Every stimulus file ships in the bundle, but a voice
  // subtest whose declared stimulus fails to load must not silently record the
  // patient answering a question they never heard.
  test('skips a voice subtest whose declared stimulus does not exist', () async {
    final s = spec('sentence-repetition-1');
    final recorder = FakeVoiceRecorder();
    final controller = build(s,
        recorder: recorder, missingAssets: {s.stimulusAsset!});

    await controller.begin();

    expect(controller.phase, SessionPhase.done);
    expect(controller.outcome!.skipped, isTrue);
    expect(controller.outcome!.maxScore, 0);
    // The point of the check: the microphone must never open for a subtest
    // whose question the patient was never asked.
    expect(recorder.calls, isEmpty);
  });

  test('runs normally once the stimulus exists', () async {
    final controller = build(spec('sentence-repetition-1'));

    await controller.begin();

    expect(controller.phase, SessionPhase.recording);
  });

  test('transcribes and scores when recording finishes', () async {
    final controller = build(spec('digit-span-forward'));

    await controller.begin();
    await controller.finishRecording();

    expect(controller.phase, SessionPhase.done);
    expect(controller.outcome!.score, 1);
    expect(controller.outcome!.transcript, 'สองหนึ่งแปดห้าสี่');
  });

  test('enters the error phase when transcription fails', () async {
    final controller = build(
      spec('digit-span-forward'),
      asr: FakeAsrClient(throws: const AsrException('offline')),
    );

    await controller.begin();
    await controller.finishRecording();

    expect(controller.phase, SessionPhase.error);
    expect(controller.error, contains('offline'));
    expect(controller.outcome, isNull);
  });

  test('retry returns to the instruction phase and clears the error', () async {
    final controller = build(
      spec('digit-span-forward'),
      asr: FakeAsrClient(throws: const AsrException('offline')),
    );

    await controller.begin();
    await controller.finishRecording();
    controller.retry();

    expect(controller.phase, SessionPhase.instruction);
    expect(controller.error, isNull);
  });

  // Skip asserts the subtest was never administered. 0 would assert the
  // patient failed, and against real MoCA cutoffs that is a fabricated finding.
  test('skip produces an outcome that is excluded from the total', () {
    final controller = build(spec('orientation'));

    final outcome = controller.skip();

    expect(outcome.skipped, isTrue);
    expect(outcome.score, 0);
    expect(outcome.maxScore, 0);
    expect(controller.phase, SessionPhase.done);
  });

  group('tap mode', () {
    testWidgets('runs the digit sequence and scores the taps', (tester) async {
      final controller = build(spec('vigilance'));

      final begun = controller.begin();
      // Lead-in, then 29 digits at 1 s each.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.phase, SessionPhase.tapping);

      await tester.pump(const Duration(milliseconds: 30000));
      await begun;

      expect(controller.phase, SessionPhase.done);
      expect(controller.outcome!.maxScore, 1);
    });

    // A press during the lead-in or after the last window is not an answer to
    // any digit, so it must not become one.
    testWidgets('ignores taps outside the tapping phase', (tester) async {
      final controller = build(spec('vigilance'));

      controller.recordTap();
      final begun = controller.begin();
      controller.recordTap();

      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      expect(controller.outcome!.detail['hits'], 0);
    });
  });
}

class _RecordingPlayback implements AudioPlayback {
  final List<String> order;
  _RecordingPlayback(this.order);

  @override
  Future<void> play(String assetPath) async {
    order.add('play-start:$assetPath');
    // A real suspension point. Without it, a caller that never awaits play()
    // would produce an order list identical to a caller that does — and this
    // test is the only thing standing between that bug and production.
    await Future<void>.delayed(Duration.zero);
    order.add('play-complete:$assetPath');
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _RecordingRecorder implements VoiceRecorder {
  final List<String> order;
  _RecordingRecorder(this.order);

  @override
  Future<void> start() async => order.add('start');
  @override
  Future<List<int>> stop() async => const [1];
  @override
  Future<void> dispose() async {}
}

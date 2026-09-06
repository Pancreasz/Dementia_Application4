import 'dart:async';

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

  // Round-2 fix: finishRecording() is the only path that writes a real score,
  // and was the only score-writing path with no generation guard. A skip
  // issued while transcription is in flight must win — a subtest the operator
  // marked never-administered must not have its skip silently overwritten by
  // a score that resolves later.
  test('a skip during in-flight transcription is not overwritten when it resolves',
      () async {
    final blocking = _BlockingAsrClient();
    final controller = build(spec('digit-span-forward'), asr: blocking);

    await controller.begin();
    final finishing = controller.finishRecording();

    final skipOutcome = controller.skip();
    blocking.gate.complete(const AsrResult(text: 'สองหนึ่งแปดห้าสี่'));
    await finishing;

    expect(controller.outcome, same(skipOutcome));
    expect(controller.outcome!.skipped, isTrue);
    expect(controller.outcome!.maxScore, 0);
  });

  // A retry followed by a second begin() must not let attempt 1's transcript
  // land once it finally resolves — attempt 2 may already have its own
  // microphone open by then.
  test('a stale finishRecording does not overwrite a later attempt', () async {
    final blocking = _BlockingAsrClient();
    final controller = build(spec('digit-span-forward'), asr: blocking);

    await controller.begin();
    final finishing = controller.finishRecording();

    controller.retry();
    await controller.begin();
    expect(controller.phase, SessionPhase.recording);

    blocking.gate.complete(const AsrResult(text: 'สองหนึ่งแปดห้าสี่'));
    await finishing;

    expect(controller.phase, SessionPhase.recording);
    expect(controller.outcome, isNull);
  });

  // The common abandonment case: the UI shows Skip/Retry exactly while
  // phase == recording, i.e. while the microphone is open. Both must close it
  // rather than leaving it live into the next subtest.
  test('skip stops an open microphone', () async {
    final recorder = FakeVoiceRecorder();
    final controller = build(spec('digit-span-forward'), recorder: recorder);

    await controller.begin();
    expect(controller.phase, SessionPhase.recording);

    controller.skip();

    expect(recorder.calls, contains('stop'));
  });

  test('retry stops an open microphone', () async {
    final recorder = FakeVoiceRecorder();
    final controller = build(spec('digit-span-forward'), recorder: recorder);

    await controller.begin();
    expect(controller.phase, SessionPhase.recording);

    controller.retry();

    expect(recorder.calls, contains('stop'));
  });

  // A double-tap on submit must not re-score: the recording is already gone
  // by the second call, so it would silently score an empty transcript over a
  // real one — a passed subtest turning into a failed one, silently.
  test('a second finishRecording call does not re-score', () async {
    final controller = build(spec('digit-span-forward'));

    await controller.begin();
    await controller.finishRecording();
    final firstOutcome = controller.outcome;

    await controller.finishRecording();

    expect(controller.outcome, same(firstOutcome));
  });

  // Guards the existing abandoned() checks against future removal: nothing
  // else in this file currently exercises two overlapping begin() calls on
  // the voice path end to end.
  test('two rapid begin calls result in exactly one playback and one microphone open',
      () async {
    final playback = FakeAudioPlayback();
    final recorder = FakeVoiceRecorder();
    final controller =
        build(spec('digit-span-forward'), playback: playback, recorder: recorder);

    final first = controller.begin();
    final second = controller.begin();
    await first;
    await second;

    expect(playback.calls.where((c) => c.startsWith('play:')).length, 1);
    expect(recorder.calls.where((c) => c == 'start').length, 1);
  });

  test('a recorder that throws on start enters the error phase', () async {
    final controller = build(
      spec('digit-span-forward'),
      recorder: FakeVoiceRecorder(throwsOnStart: StateError('mic denied')),
    );

    await controller.begin();

    expect(controller.phase, SessionPhase.error);
    expect(controller.outcome, isNull);
  });

  // Navigating back during transcription needs no UI race: begin() itself can
  // be suspended (mid-playback) when dispose() arrives. A resumed begin() must
  // not touch the now-disposed recorder or notify a disposed ChangeNotifier.
  test('dispose during an in-flight begin does not resume into a disposed controller',
      () async {
    final gated = _GatedPlayback();
    final recorder = FakeVoiceRecorder();
    final controller =
        build(spec('digit-span-forward'), playback: gated, recorder: recorder);

    final begun = controller.begin();
    // Let assetExists resolve and playback.play() be called, but not finish.
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, SessionPhase.stimulus);

    controller.dispose();
    gated.gate.complete();

    await begun;

    // dispose() itself legitimately calls recorder.dispose() — what must
    // never happen is the resumed begin() calling recorder.start() on it.
    expect(recorder.calls, isNot(contains('start')));
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

    // Mirrors the voice-path safety net: if the digit audio cannot play, the
    // patient hears nothing and taps nothing, and scoring must not record a
    // real 0/1 for a task never administered.
    testWidgets('skips vigilance when the stimulus is missing', (tester) async {
      final controller = build(
        spec('vigilance'),
        missingAssets: {'assets/moca/audio/vigilance.wav'},
      );

      final begun = controller.begin();
      // Enough pumped time for the full 29-digit sequence to run to
      // completion if the missing-asset check were not in place, so this
      // test distinguishes "skipped immediately" from "hung waiting for a
      // digit sequence that never got scheduled".
      await tester.pump(const Duration(milliseconds: 32000));
      await begun;

      expect(controller.phase, SessionPhase.done);
      expect(controller.outcome!.skipped, isTrue);
      expect(controller.outcome!.maxScore, 0);
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
  Future<void> load(String assetPath) async => order.add('load:$assetPath');
  @override
  Future<void> start() async => order.add('start');
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

/// An ASR client whose transcribe() never resolves until the test completes
/// [gate] — lets a test act (skip, retry, a second begin) while
/// finishRecording() is genuinely suspended waiting on the network, the same
/// way a real transcription request would be.
class _BlockingAsrClient implements AsrClient {
  final Completer<AsrResult> gate = Completer<AsrResult>();

  @override
  Future<AsrResult> transcribe(List<int> audioBytes, {String language = 'th'}) =>
      gate.future;
}

/// Playback that never resolves until the test completes [gate] — lets a test
/// dispose the controller while begin() is genuinely suspended mid-stimulus.
class _GatedPlayback implements AudioPlayback {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> play(String assetPath) => gate.future;
  @override
  Future<void> load(String assetPath) async {}
  @override
  Future<void> start() => gate.future;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

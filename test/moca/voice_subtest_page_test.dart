import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/audio_player.dart';
import 'package:moca_main/moca/audio_recorder.dart';
import 'package:moca_main/moca/session_controller.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/moca/voice_subtest_page.dart';
import 'package:moca_main/pages/score.dart' as globals;

/// Fails the first transcription and succeeds on every call after, so a
/// retry test can prove the second attempt actually goes through rather than
/// just that the retry button exists.
class _FlakyOnceAsrClient implements AsrClient {
  int callCount = 0;

  @override
  Future<AsrResult> transcribe(List<int> audioBytes, {String language = 'th'}) async {
    callCount += 1;
    if (callCount == 1) {
      throw const AsrException('offline');
    }
    return const AsrResult(text: 'ยานพาหนะ');
  }
}

/// Never returns, standing in for a backend that has accepted the upload and
/// gone quiet. The real client gives up after 180 s; these tests need the state
/// the patient is in for those three minutes, so this one never gives up at all
/// — if the Skip button did not exist, the test would hang exactly as the app
/// would.
class _HangingAsrClient implements AsrClient {
  @override
  Future<AsrResult> transcribe(List<int> audioBytes, {String language = 'th'}) =>
      Completer<AsrResult>().future;
}

/// The same idea for stimulus playback: a device whose audio output never
/// reports completion leaves play()'s future pending forever.
class _HangingAudioPlayback implements AudioPlayback {
  bool stopped = false;

  @override
  Future<void> play(String assetPath) => Completer<void>().future;

  @override
  Future<void> load(String assetPath) async {}

  @override
  Future<void> start() => Completer<void>().future;

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(globals.voiceOutcomes.clear);

  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  Widget host(
    SubtestSpec s, {
    AsrClient? asr,
    AudioPlayback? playback,
    Future<bool> Function(String)? assetExists,
  }) =>
      MaterialApp(
        home: VoiceSubtestPage(
          spec: s,
          nextRoute: '/next',
          controllerFactory: (spec) => SubtestSessionController(
            spec: spec,
            asr: asr ?? FakeAsrClient(text: 'ยานพาหนะ'),
            recorder: FakeVoiceRecorder(),
            playback: playback ?? FakeAudioPlayback(),
            assetExists: assetExists,
          ),
        ),
        routes: {'/next': (_) => const Scaffold(body: Text('NEXT PAGE'))},
      );

  testWidgets('shows the Thai instruction text and a start button',
      (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1')));

    expect(find.text(spec('abstraction-1').instructionTh), findsOneWidget);
    expect(find.text('เริ่ม'), findsOneWidget);
  });

  testWidgets('records, scores, and moves to the next route', (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['abstraction-1']!.score, 1);
  });

  testWidgets('offers retry and skip when transcription fails',
      (tester) async {
    await tester.pumpWidget(
        host(spec('abstraction-1'), asr: FakeAsrClient(throws: const AsrException('offline'))));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('ลองใหม่'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
  });

  testWidgets('skipping records a skipped outcome and advances',
      (tester) async {
    await tester.pumpWidget(
        host(spec('abstraction-1'), asr: FakeAsrClient(throws: const AsrException('offline'))));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้าม'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['abstraction-1']!.skipped, isTrue);
  });

  testWidgets(
      'a transcription that never returns can still be skipped out of',
      (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1'), asr: _HangingAsrClient()));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pump();

    // Stuck in the scoring phase with the request outstanding. Before the skip
    // control existed this screen had no controls at all, and PopScope blocks
    // the back gesture, so the only way out was a force-quit — which loses the
    // whole session, nothing being persisted.
    expect(find.text('กำลังตรวจคำตอบ'), findsOneWidget);

    await tester.tap(find.text('ข้ามข้อนี้'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    // Skipped, not 0: a hung backend must not assert the patient failed.
    expect(globals.voiceOutcomes['abstraction-1']!.skipped, isTrue);
    expect(globals.voiceOutcomes['abstraction-1']!.maxScore, 0);
  });

  testWidgets('stimulus playback that never finishes can be skipped out of',
      (tester) async {
    final playback = _HangingAudioPlayback();
    await tester.pumpWidget(host(
      spec('sentence-repetition-1'),
      playback: playback,
      // rootBundle asset resolution is not dependable under flutter_test, and
      // a false negative here would skip before ever reaching the stimulus
      // phase this test is about.
      assetExists: (_) async => true,
    ));

    await tester.tap(find.text('เริ่ม'));
    await tester.pump();

    expect(find.text('กำลังเล่นเสียง กรุณาฟัง'), findsOneWidget);

    await tester.tap(find.text('ข้ามข้อนี้'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['sentence-repetition-1']!.skipped, isTrue);
    // The prompt is silenced on the way out rather than playing on over the
    // next subtest.
    expect(playback.stopped, isTrue);
  });

  testWidgets('a completed subtest prints its transcript and score',
      (tester) async {
    // score_log_test.dart covers the formatting; this covers the wiring, which
    // is the half that silently stops working if _onPhaseChanged is reordered.
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');

    try {
      await tester.pumpWidget(
          host(spec('abstraction-1'), asr: FakeAsrClient(text: 'ยานพาหนะ')));

      await tester.tap(find.text('เริ่ม'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();
    } finally {
      // testWidgets asserts every foundation debug variable is back to its
      // default before tearDowns run, so this cannot be an addTearDown.
      debugPrint = original;
    }

    final logged = lines.where((l) => l.startsWith('[MoCA]')).toList();
    expect(logged, hasLength(1));
    expect(logged.single, contains('abstraction-1'));
    expect(logged.single, contains('1/1'));
    expect(logged.single, contains('heard: "ยานพาหนะ"'));
  });

  testWidgets('a skipped subtest is logged too, and not as a zero',
      (tester) async {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');

    try {
      await tester.pumpWidget(host(spec('abstraction-1'),
          asr: FakeAsrClient(throws: const AsrException('offline'))));

      await tester.tap(find.text('เริ่ม'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ข้าม'));
      await tester.pumpAndSettle();
    } finally {
      debugPrint = original;
    }

    final logged = lines.where((l) => l.startsWith('[MoCA]')).toList();
    expect(logged, hasLength(1));
    expect(logged.single, contains('SKIPPED'));
  });

  testWidgets('a tap subtest shows a tap button instead of a mic button',
      (tester) async {
    await tester.pumpWidget(host(spec('vigilance')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('เคาะ'), findsOneWidget);
    expect(find.text('ส่งคำตอบ'), findsNothing);

    await tester.pump(const Duration(milliseconds: 30000));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'verbal fluency auto-submits at the 60-second deadline without a tap on ส่งคำตอบ',
      (tester) async {
    await tester.pumpWidget(host(spec('verbal-fluency')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();

    // In the recording phase: the submit button is present, but the test
    // never taps it. Everything from here on must happen off the timer.
    expect(find.text('ส่งคำตอบ'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['verbal-fluency'], isNotNull);
    expect(globals.voiceOutcomes['verbal-fluency']!.skipped, isFalse);
  });

  testWidgets(
      'a subtest without an enforced deadline does not auto-submit past 60 seconds',
      (tester) async {
    await tester.pumpWidget(host(spec('abstraction-1')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();

    expect(find.text('ส่งคำตอบ'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));

    // No enforceTimeLimit on this subtest: still waiting on the patient.
    expect(find.text('ส่งคำตอบ'), findsOneWidget);
    expect(find.text('NEXT PAGE'), findsNothing);
    expect(globals.voiceOutcomes['abstraction-1'], isNull);
  });

  testWidgets('a tap inside a target window is scored as a hit',
      (tester) async {
    await tester.pumpWidget(host(spec('vigilance')));

    await tester.tap(find.text('เริ่ม'));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('เคาะ'), findsOneWidget);

    // The controller times taps against a real DateTime.now() (see
    // digit_sequence_player.dart / session_controller.dart), which
    // WidgetTester.pump's fake clock does not advance — only Timer firing is
    // faked, not DateTime.now(). tester.runAsync() steps outside the fake
    // zone for a genuine wall-clock wait so the tap lands inside a real
    // target window. Digit index 2 (the sequence's third character) is a
    // target ('1'); its window is [2000, 3000) ms after the first digit's
    // onset, so a ~2.5s real wait lands mid-window.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 2500));
    });

    await tester.tap(find.text('เคาะ'));

    await tester.pump(const Duration(milliseconds: 30000));
    await tester.pumpAndSettle();

    final outcome = globals.voiceOutcomes['vigilance'];
    expect(outcome, isNotNull);
    expect((outcome!.detail['hits'] as int), greaterThan(0));
  });

  testWidgets(
      'retry returns to the instruction phase and the subtest can then complete',
      (tester) async {
    final flaky = _FlakyOnceAsrClient();
    await tester.pumpWidget(host(spec('abstraction-1'), asr: flaky));

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('ลองใหม่'), findsOneWidget);

    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    // Back at the instruction phase, not stuck on the error screen and not
    // yet navigated away.
    expect(find.text('เริ่ม'), findsOneWidget);
    expect(find.text('NEXT PAGE'), findsNothing);

    await tester.tap(find.text('เริ่ม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(find.text('NEXT PAGE'), findsOneWidget);
    expect(globals.voiceOutcomes['abstraction-1']!.skipped, isFalse);
    expect(flaky.callCount, 2);
  });
}

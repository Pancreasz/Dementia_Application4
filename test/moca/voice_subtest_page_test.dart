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

void main() {
  setUp(globals.voiceOutcomes.clear);

  SubtestSpec spec(String id) => kVoiceSubtests.firstWhere((s) => s.id == id);

  Widget host(SubtestSpec s, {AsrClient? asr}) => MaterialApp(
        home: VoiceSubtestPage(
          spec: s,
          nextRoute: '/next',
          controllerFactory: (spec) => SubtestSessionController(
            spec: spec,
            asr: asr ?? FakeAsrClient(text: 'ยานพาหนะ'),
            recorder: FakeVoiceRecorder(),
            playback: FakeAudioPlayback(),
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

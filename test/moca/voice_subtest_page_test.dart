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
}

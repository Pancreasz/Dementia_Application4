import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/event_trace.dart';
import 'package:moca_main/moca/live_session.dart';
import 'package:moca_main/moca/session_record.dart';
import 'package:moca_main/moca/session_store.dart';
import 'package:moca_main/pages/larksen.dart';
import 'package:moca_main/pages/score.dart' as globals;

/// Nothing on disk: a widget test runs in a fake-async zone, where a real file
/// write never completes and the test hangs rather than failing.
class _FakeStore implements SessionStore {
  @override
  Future<void> save(SessionRecord record) async {}
  @override
  Future<SessionRecord?> load(String id) async => null;
  @override
  Future<List<SessionRecord>> loadAll() async => const [];
  @override
  Future<SessionRecord?> loadResumable() async => null;
  @override
  Future<void> delete(String id) async {}
}

/// What the trail-making page writes down while it is being drawn on.
///
/// The analysis of this subtest is only as good as this capture, and the
/// capture is invisible on screen: nothing here changes a pixel, so nothing
/// but a test can notice it breaking.
void main() {
  setUp(() {
    AppLanguage.current = Language.en;
    LiveSession.clearCurrent();
    globals.larkScore = 0;
  });

  tearDown(() {
    AppLanguage.current = Language.th;
    LiveSession.clearCurrent();
  });

  Widget app() => MaterialApp(
        routes: {'/clock': (_) => const Scaffold(body: Text('CLOCK PAGE'))},
        home: const GameScreen(),
      );

  /// Opens the page and dismisses the instruction dialog, which is what starts
  /// the clock.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
  }

  /// One finger-down, two moves, finger-up.
  Future<void> drawLine(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  List<TraceEvent> events() =>
      LiveSession.current!.trace.forSubtest(trailSubtestId);

  List<TraceEvent> ofType(String type) =>
      events().where((e) => e.type == type).toList();

  testWidgets('a stroke is recorded with every point and when it was touched',
      (tester) async {
    await LiveSession.start(store: _FakeStore());
    await open(tester);

    await drawLine(tester, const Offset(120, 300), const Offset(320, 300));

    final strokes = ofType(TraceEventType.stroke);
    expect(strokes, hasLength(1));

    final points = (strokes.single.data['points'] as List).cast<List>();
    // At least the finger-down and the finger-up. The platform decides how
    // many samples land in between, and the capture keeps all of them.
    expect(points.length, greaterThanOrEqualTo(2));

    for (final p in points) {
      expect(p, hasLength(3), reason: 'x, y and a time');
      expect(p[0], isA<int>());
      expect(p[1], isA<int>());
      expect(p[2], isA<int>());
    }

    // Times share the trace's clock, so they are offsets from the start of the
    // session and only ever move forwards.
    var previous = -1;
    for (final p in points) {
      final ms = p[2] as int;
      expect(ms, greaterThanOrEqualTo(0));
      expect(ms, greaterThanOrEqualTo(previous));
      previous = ms;
    }

    expect(strokes.single.data['index'], 0);
    expect(strokes.single.data['attempt'], 0);
  });

  testWidgets('strokes are numbered in the order they were drawn',
      (tester) async {
    await LiveSession.start(store: _FakeStore());
    await open(tester);

    await drawLine(tester, const Offset(120, 200), const Offset(300, 200));
    await drawLine(tester, const Offset(120, 400), const Offset(300, 400));

    expect([for (final e in ofType(TraceEventType.stroke)) e.data['index']],
        [0, 1]);
  });

  testWidgets('a touch too short to draw a line is still recorded',
      (tester) async {
    // A finger put down on a point and lifted again draws nothing, and is
    // exactly the hesitation this capture exists to keep.
    await LiveSession.start(store: _FakeStore());
    await open(tester);

    final gesture = await tester.startGesture(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(ofType(TraceEventType.stroke), hasLength(1));
  });

  testWidgets('the point layout and the screen it was laid out on are recorded',
      (tester) async {
    // Without this, a move time is uninterpretable: the ten points are placed
    // at random, so the distance between two of them is different every time.
    await LiveSession.start(store: _FakeStore());
    await open(tester);

    final placed = ofType(TraceEventType.checkpointsPlaced);
    expect(placed, hasLength(1));
    expect((placed.single.data['points'] as List), hasLength(10));
    expect((placed.single.data['labels'] as List), hasLength(10));
    expect(placed.single.data['width'], isA<int>());
    expect(placed.single.data['height'], isA<int>());
  });

  testWidgets('the clock starts when the instructions are dismissed',
      (tester) async {
    await LiveSession.start(store: _FakeStore());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(ofType(TraceEventType.started), isEmpty);
    expect(ofType(TraceEventType.instructionShown), hasLength(1));

    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();

    expect(ofType(TraceEventType.started), hasLength(1));
  });

  testWidgets('a restart opens a new attempt and renumbers from zero',
      (tester) async {
    await LiveSession.start(store: _FakeStore());
    await open(tester);
    await drawLine(tester, const Offset(120, 300), const Offset(320, 300));

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(ofType(TraceEventType.retried), hasLength(1));
    // A fresh layout, because the points are generated again.
    expect(ofType(TraceEventType.checkpointsPlaced), hasLength(2));
    expect(ofType(TraceEventType.checkpointsPlaced).last.data['attempt'], 1);

    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
    await drawLine(tester, const Offset(120, 400), const Offset(320, 400));

    final second = ofType(TraceEventType.stroke).last;
    expect(second.data['attempt'], 1);
    expect(second.data['index'], 0, reason: 'stroke numbering is per attempt');
  });

  testWidgets('submitting records the score and why it was lost',
      (tester) async {
    await LiveSession.start(store: _FakeStore());
    await open(tester);
    // One line between two arbitrary places on the canvas cannot be a correct
    // solution, and it does not cross itself either.
    await drawLine(tester, const Offset(120, 300), const Offset(320, 300));

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    final scored = ofType(TraceEventType.scored);
    expect(scored, hasLength(1));
    expect(scored.single.data['score'], 0);
    expect(scored.single.data['maxScore'], 1);
    expect(scored.single.data['linesCross'], isFalse);
    expect(globals.larkScore, 0);
  });

  testWidgets('the page still works when nothing is recording', (tester) async {
    // No session at all — the capture must be a no-op, not a crash in front of
    // a patient.
    await open(tester);
    await drawLine(tester, const Offset(120, 300), const Offset(320, 300));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('CLOCK PAGE'), findsOneWidget);
  });
}

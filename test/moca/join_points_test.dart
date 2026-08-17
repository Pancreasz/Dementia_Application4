// The three route literals below are hand-edited, not derived from
// routeFor(), so a typo or a revert in any of them would compile cleanly and
// keep the rest of the suite green while silently dropping the nine-subtest
// chain at runtime. These tests pump the real pages and assert on the actual
// route name each one hands off to.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/pages/animal.dart';
import 'package:moca_main/pages/roiLobJed.dart';

/// Captures every route name the Navigator pushes OR replaces with, since
/// AnimalMocaTestPage finishes its quiz via pushReplacementNamed (which fires
/// didReplace, not didPush).
class _RouteRecorder extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = newRoute?.settings.name;
    if (name != null) pushed.add(name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() {
  testWidgets(
      'AnimalMocaTestPage pushes /digit-span-forward once the quiz finishes',
      (tester) async {
    final recorder = _RouteRecorder();
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [recorder],
      home: const AnimalMocaTestPage(),
      routes: {
        '/digit-span-forward': (_) => const Scaffold(body: Text('NEXT')),
      },
    ));

    // Dismiss the welcome dialog shown on the first frame.
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();

    // Three animal images are quizzed; the answer's correctness does not
    // gate navigation, only reaching the third submission does.
    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.text('ส่งคำตอบ'));
      await tester.pumpAndSettle();
    }

    expect(recorder.pushed, contains('/digit-span-forward'));
  });

  testWidgets('AttentionTestPage pushes /sentence-repetition-1 on submit',
      (tester) async {
    final recorder = _RouteRecorder();
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [recorder],
      home: const AttentionTestPage(),
      routes: {
        '/sentence-repetition-1': (_) => const Scaffold(body: Text('NEXT')),
      },
    ));

    await tester.tap(find.text('ส่งคำตอบ'));
    await tester.pumpAndSettle();

    expect(recorder.pushed, contains('/sentence-repetition-1'));
  });

  // ReorderImagesPage gates its navigation behind five completed drag-and-
  // drop placements (_canSubmit()), reached only through Draggable/DragTarget
  // gestures. Driving that in a widget test proved impractical: the page's
  // real render tree (Scaffold -> Material -> SingleChildScrollView ->
  // LayoutBuilder-driven Wrap/DragTarget grid) puts something between the
  // synthetic pointer and the Draggable's own hit-test region — tester.drag()
  // consistently warns that its derived offset does not hit test onto the
  // Draggable it targeted, even after enlarging the test surface to keep the
  // whole layout on screen, so no drop is ever registered and _canSubmit()
  // never becomes true. Rather than adapt the page to make it testable (out
  // of scope — it is a working, already-shipped subtest), this asserts the
  // hand-edited route literal directly against the source, the fallback the
  // task brief allows for this page.
  test(
      'ReorderImagesPage source pushes /orientation from _submitAnswers (route literal check — see comment above)',
      () {
    final source =
        File('lib/pages/reorder_images_page.dart').readAsStringSync();

    expect(
      source,
      contains("Navigator.pushNamed(context, '/orientation');"),
      reason: 'the hand-edited join-point route literal must read exactly '
          "'/orientation'",
    );

    // Guard against the literal appearing more than once, which would make
    // the contains() check above too weak to mean anything.
    final occurrences =
        "Navigator.pushNamed(context, '/orientation');".allMatches(source).length;
    expect(occurrences, 1);
  });
}

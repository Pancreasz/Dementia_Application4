import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/pages/clock.dart';

void main() {
  // Regression test for a real bug: the backend model is trained on
  // white-background clock photos. PIL's `Image.open(...).convert("RGB")`
  // does not composite a transparent background onto white -- it keeps the
  // raw RGB channel values, which for an untouched canvas pixel are
  // (0,0,0,0). A transparent capture therefore arrives at the backend as
  // black, not white, and the model scores it 0-1 no matter how good the
  // drawing is. LinePainter must bake an opaque white background into the
  // captured layer itself, since the RepaintBoundary only captures
  // LinePainter's output, not the parent Container's BoxDecoration.
  testWidgets(
    'captured drawing has an opaque white background, not a transparent one',
    (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: CustomPaint(
              size: const Size(100, 100),
              painter: LinePainter(const []),
            ),
          ),
        ),
      );

      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // toImage() rasterizes for real; it never resolves inside testWidgets'
      // fake-async zone, so it must run on the real event loop.
      final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
        final ui.Image image = await boundary.toImage();
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      });

      // Sample a background pixel (no lines drawn near the corner).
      final pixels = bytes!.buffer.asUint8List();
      final r = pixels[0];
      final g = pixels[1];
      final b = pixels[2];
      final a = pixels[3];

      expect(
        a,
        255,
        reason: 'background must be fully opaque, not transparent',
      );
      expect(
        [r, g, b],
        [255, 255, 255],
        reason: 'background must be white to match the clock model\'s '
            'training distribution',
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asset_preload.dart';

/// The image preload that runs once, from the home page, so the naming
/// animals and the trail-making GIF are already fetched by the time a patient
/// reaches the page that shows them — see asset_preload.dart for why that
/// matters on the web build.
///
/// Everything real here runs inside [WidgetTester.runAsync]: image decoding
/// goes through the real platform codec, which never resolves inside
/// `testWidgets`' fake-async zone — it hangs rather than failing, the same way
/// real file I/O does.
void main() {
  /// The still images. Separated from the animated GIF throughout this file
  /// because precacheImage behaves fundamentally differently on the two.
  final stillImages =
      kPreloadableImages.where((p) => !p.endsWith('.gif')).toList();

  setUp(() => PaintingBinding.instance.imageCache.clear());

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    }));
    return ctx;
  }

  testWidgets('every still image in the list is a real, loadable asset',
      (tester) async {
    // If this list drifts from pubspec.yaml (a rename, a typo, an asset
    // removed) this is what catches it — not a blank box shown to a patient
    // weeks later.
    final ctx = await pumpContext(tester);
    await tester.runAsync(() async {
      for (final path in stillImages) {
        await precacheImage(AssetImage(path), ctx);
      }
    });
    expect(PaintingBinding.instance.imageCache.currentSize, stillImages.length);
  });

  testWidgets('the animated GIF is in the list, and is the only one',
      (tester) async {
    // preloadAppImages routes .gif entries to warmAssetBytes instead of
    // precacheImage; this pins that there is exactly one such entry to route.
    expect(kPreloadableImages.where((p) => p.endsWith('.gif')), hasLength(1));
  });

  testWidgets('preloading the still images populates the shared cache',
      (tester) async {
    final ctx = await pumpContext(tester);
    expect(PaintingBinding.instance.imageCache.currentSize, 0);
    await tester.runAsync(() => preloadImages(ctx, stillImages));
    expect(PaintingBinding.instance.imageCache.currentSize, stillImages.length);
  });

  testWidgets('a missing asset does not stop the rest from loading',
      (tester) async {
    final ctx = await pumpContext(tester);
    await tester.runAsync(() => preloadImages(
        ctx, const ['assets/does-not-exist.png', 'assets/lion.png']));
    expect(PaintingBinding.instance.imageCache.currentSize, 1);
  });

  testWidgets('the animated GIF loads as bytes, which precaching cannot do',
      (tester) async {
    // The whole reason warmAssetBytes exists: precacheImage on this asset
    // never completes. Loading its bytes must, and quickly.
    await tester.runAsync(
        () => warmAssetBytes(const ['assets/larksen_tutorial.gif']));
  });

  testWidgets('preloadAppImages completes, GIF included', (tester) async {
    // The end-to-end guarantee HomePage depends on: this must not hang, or
    // the app would sit on a blank home screen behind a never-finishing
    // future.
    final ctx = await pumpContext(tester);
    await tester.runAsync(() => preloadAppImages(ctx));
    expect(PaintingBinding.instance.imageCache.currentSize, stillImages.length);
  });

  testWidgets('a missing animated asset is tolerated too', (tester) async {
    await tester.runAsync(() => warmAssetBytes(const ['assets/nope.gif']));
  });

  testWidgets('preloading twice does not double the cache', (tester) async {
    final ctx = await pumpContext(tester);
    await tester.runAsync(() async {
      await preloadImages(ctx, stillImages);
      await preloadImages(ctx, stillImages);
    });
    expect(PaintingBinding.instance.imageCache.currentSize, stillImages.length);
  });
}

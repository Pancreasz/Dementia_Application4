import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

/// Every image asset a subtest page draws, fetched once up front.
///
/// WHY THIS EXISTS
/// ----------------
/// `Image.asset` fetches lazily, on the frame it first appears. On the web
/// build that fetch is a real network request for the asset bundle entry, and
/// nothing forces it to finish before the widget needs it — a slow or
/// momentarily flaky connection leaves a blank box (or, worse, a decode that
/// races the paint) exactly when a patient is mid-assessment and cannot be
/// asked to simply reload. The naming animals and the trail-making tutorial
/// GIF were both reported doing this.
///
/// Loading them all right after the app opens — before the patient has
/// reached the page that needs them — turns that network request into idle
/// time nobody is waiting on, instead of a stall in the middle of a subtest.
///
/// [precacheImage] populates Flutter's process-wide [PaintingBinding.imageCache],
/// not anything scoped to the calling widget, so a page reached minutes later
/// finds its image already decoded regardless of who triggered the fetch.
/// Both kinds of asset live in one list; [preloadAppImages] splits them by
/// extension and loads each the way that actually works for it.
const List<String> kPreloadableImages = [
  'assets/lion.png',
  'assets/camel.png',
  'assets/rhino.png',
  'assets/img1.jpg',
  'assets/img2.jpg',
  'assets/img3.jpg',
  'assets/img4.jpg',
  'assets/img5.jpg',
  'assets/img6.jpg',
  'assets/img7.jpg',
  'assets/img8.jpg',
  'assets/img9.jpg',
  'assets/img10.jpg',
  'assets/larksen_tutorial.gif',
];

/// Precaches [paths], one at a time, and never throws.
///
/// Sequential rather than [Future.wait]-in-parallel: these are small files on
/// a connection that is already the bottleneck, and racing a dozen requests
/// against each other on a poor connection is more likely to time all of them
/// out than to finish any of them sooner.
///
/// A missing, corrupt, or non-completing asset must not stop the rest from
/// loading, and must certainly not crash or wedge the app on startup — this is
/// a performance nicety, not a requirement, and the pages that use these
/// images already fall back gracefully (see `animal.dart`'s `errorBuilder`).
Future<void> preloadImages(BuildContext context, List<String> paths) async {
  for (final path in paths) {
    try {
      await precacheImage(
        AssetImage(path),
        // ignore: use_build_context_synchronously
        context,
        // Without this, a missing asset is ALSO reported to FlutterError,
        // which paints a red error box in debug and fails any widget test
        // that happens to be running — for something this function is
        // deliberately choosing to tolerate.
        onError: (_, __) {},
      );
    } catch (_) {
      // Deliberately swallowed. A preload that fails costs a slower first
      // paint, nothing more.
    }
  }
}

/// Fetches [paths] as raw bytes, warming the asset cache without decoding.
///
/// WHY ANIMATED IMAGES CANNOT GO THROUGH [preloadImages]
/// -----------------------------------------------------
/// [precacheImage] never completes for an animated image: its completer waits
/// on a single decoded frame and a multi-frame codec keeps producing them.
/// `larksen_tutorial.gif` is animated, so precaching it would hang the
/// sequential loop above forever and silently skip everything queued behind
/// it. Confirmed under `flutter test`, where it hangs rather than failing.
///
/// Bounding that with a timeout was the first fix and was worse: a pending
/// [Timer] outlives the widget tree and fails every widget test that mounts a
/// page doing this. Fetching bytes avoids the problem instead of managing it —
/// and decoding was never the point. What makes the GIF slow is the download,
/// and [rootBundle] caches what it loads, so the later `Image.asset` finds the
/// bytes already in memory and decodes them locally.
Future<void> warmAssetBytes(List<String> paths) async {
  for (final path in paths) {
    try {
      await rootBundle.load(path);
    } catch (_) {
      // Same tolerance as above.
    }
  }
}

/// Preloads every image this app shows during an assessment.
///
/// Still images are decoded into the image cache; the animated GIF is only
/// fetched as bytes, for the reason given on [warmAssetBytes].
Future<void> preloadAppImages(BuildContext context) async {
  final still = [for (final p in kPreloadableImages) if (!_isAnimated(p)) p];
  final animated = [for (final p in kPreloadableImages) if (_isAnimated(p)) p];
  await preloadImages(context, still);
  await warmAssetBytes(animated);
}

bool _isAnimated(String path) => path.toLowerCase().endsWith('.gif');

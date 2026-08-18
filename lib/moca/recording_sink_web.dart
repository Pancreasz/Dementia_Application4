import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Browser: there is no filesystem. `record_web` accumulates the take in an
/// in-memory Blob and `stop()` returns `URL.createObjectURL(blob)`.
class PlatformRecordingSink {
  /// `record_web` accepts a path and ignores it — the Blob is the destination.
  /// Returned empty rather than a fake filename so nothing downstream is
  /// tempted to treat it as one.
  Future<String> newTarget() async => '';

  /// [handle] is whatever `AudioRecorder.stop()` returned — here, a `blob:`
  /// URL. Reading it back through http is not a network request: the browser
  /// resolves `blob:` URLs straight out of the same in-memory store.
  Future<List<int>> readAndRelease(String? handle) async {
    if (handle == null || handle.isEmpty) return const [];

    final response = await http.get(Uri.parse(handle));

    // Without this the Blob is pinned for the lifetime of the tab. Nine
    // subtests of 16 kHz mono WAV — verbal fluency alone is a full 60 seconds —
    // is tens of megabytes a single session never gives back.
    web.URL.revokeObjectURL(handle);

    return response.bodyBytes;
  }
}

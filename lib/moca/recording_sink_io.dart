import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Desktop and mobile: `record` writes a real WAV file to the temp directory.
class PlatformRecordingSink {
  /// The path `record` should write this take to.
  Future<String> newTarget() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/moca-${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  /// [handle] is whatever `AudioRecorder.stop()` returned — here, a file path.
  Future<List<int>> readAndRelease(String? handle) async {
    if (handle == null || handle.isEmpty) return const [];

    final file = File(handle);
    if (!await file.exists()) return const [];
    final bytes = await file.readAsBytes();

    // The upload is the only consumer; leaving these behind fills the temp
    // directory over a long session.
    try {
      await file.delete();
    } catch (_) {}

    return bytes;
  }
}

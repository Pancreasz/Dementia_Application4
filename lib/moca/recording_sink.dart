/// Where a recording physically lives between `stop()` and the upload, which is
/// the one part of the microphone path that is genuinely different on the web.
///
/// On desktop/mobile `record` writes a file and hands back its path. On the web
/// there is no filesystem: it accumulates an in-memory Blob and hands back a
/// `blob:` URL. `dart:io` and `path_provider` compile on the web but throw the
/// moment they are touched, so the two cases cannot share one body — hence the
/// conditional import rather than a `kIsWeb` branch.
///
/// The default is the io implementation, which is also what `flutter test`
/// picks up: `dart.library.js_interop` is absent on the VM.
library;

export 'recording_sink_io.dart'
    if (dart.library.js_interop) 'recording_sink_web.dart';

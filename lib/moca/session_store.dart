/// Where a session physically persists, which is the one part of this that is
/// genuinely different on the web.
///
/// On desktop/mobile it is a JSON file under the app's documents directory. On
/// the web there is no filesystem, so it is localStorage. `dart:io` and
/// `path_provider` compile on the web but throw the moment they are touched,
/// so the two cases cannot share one body — hence the conditional import
/// rather than a `kIsWeb` branch, matching `recording_sink.dart`.
///
/// The default is the io implementation, which is also what `flutter test`
/// picks up: `dart.library.js_interop` is absent on the VM.
library;

export 'session_store_io.dart'
    if (dart.library.js_interop) 'session_store_web.dart';

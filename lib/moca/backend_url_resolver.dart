/// Where the runtime backend-URL override (web only) is read from. See
/// `recording_sink.dart` for the same conditional-export shape and why it's
/// used instead of a `kIsWeb` branch: the two implementations don't share a
/// body, so branching at import time keeps the io side free of anything
/// browser-only.
library;

export 'backend_url_resolver_io.dart'
    if (dart.library.js_interop) 'backend_url_resolver_web.dart';

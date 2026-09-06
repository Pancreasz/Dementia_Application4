import 'backend_url_resolver.dart';

/// The one place the backend's location is written down.
///
/// Both endpoints below used to be spelled out in full, separately: the ASR one
/// in `moca/asr_client.dart` and the clock one in `pages/clock.dart`. Both
/// pointed at an Azure deployment that is no longer live, so moving hosts meant
/// editing two files, one of them an otherwise-untouched original page. Now it
/// is this constant.
///
/// The default is the local FastAPI backend in `backend/` — start it with
/// `uvicorn app:app --host 0.0.0.0 --port 8000` from that directory. A
/// different host needs no code change:
///
/// ```
/// flutter run -d windows --dart-define=MOCA_BACKEND_BASE_URL=https://example.net
/// ```
///
/// The published GitHub Pages build can't use `--dart-define` for this the
/// same way — the backend there is often a Cloudflare quick tunnel, which
/// gets a new hostname every restart, and re-baking + redeploying the site
/// each time isn't practical. On web, `?backend=<url>` in the page's own
/// address overrides this at runtime instead, and is remembered in
/// localStorage so reopening the link later (no query param) still uses it.
/// See `backend_url_resolver_web.dart`. Not `const` for that reason — it's
/// resolved once, lazily, on first read.
///
/// No trailing slash: the paths below concatenate directly.
final String kBackendBaseUrl = resolveBackendBaseUrl(
  const String.fromEnvironment(
    'MOCA_BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8000',
  ),
);

/// Thai Whisper transcription, used by every voice subtest.
final String kTranscribeEndpoint = '$kBackendBaseUrl/transcribe';

/// Clock-drawing DenseNet. Its response's `predicted_moca_score` must be a JSON
/// integer — `clock.dart` assigns it straight to a Dart `int`.
final String kClockUploadEndpoint = '$kBackendBaseUrl/upload';

/// Liveness probe. Nothing calls this yet; it is here so a future pre-flight
/// check does not reintroduce a second spelling of the base URL.
final String kHealthEndpoint = '$kBackendBaseUrl/health';

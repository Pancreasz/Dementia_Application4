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
/// No trailing slash: the paths below concatenate directly. Normalized rather
/// than merely documented — see [normalizeBackendBaseUrl].
final String kBackendBaseUrl = redirectRetiredBackendUrl(
  normalizeBackendBaseUrl(
    resolveBackendBaseUrl(
      const String.fromEnvironment(
        'MOCA_BACKEND_BASE_URL',
        defaultValue: 'http://localhost:8000',
      ),
    ),
  ),
);

/// Tunnel hostnames that are printed on something we cannot reprint, mapped to
/// where that traffic should go now.
///
/// WHY A HARDCODED MAP IS THE RIGHT SHAPE HERE
/// -------------------------------------------
/// A QR code was printed on 2026-09-09 encoding
/// `…/Dementia_Application4/?backend=https://basic-shopzilla-similar-daisy.trycloudflare.com`.
/// That tunnel is gone. The QR is on paper, GitHub Pages serves static files
/// and cannot redirect, and the query param is read by this app — so the only
/// place left that can act on it is this app. Whoever scans the paper gets a
/// dead backend otherwise, and the failure looks like "the assessment is
/// broken", not "the link is old".
///
/// Every entry here is a promise to keep a specific machine reachable at a
/// specific hostname. Add one only for a link that is genuinely out of reach —
/// a printed sheet, a sent email — never as a substitute for sharing a current
/// link, and delete it once the paper is out of circulation.
const Map<String, String> kRetiredBackendUrls = {
  // Printed QR, 2026-09-09. The replacement is a quick tunnel too, so it is
  // only stable for as long as that PC stays up; the repo owner accepted that
  // explicitly when asking for this. If it ever does restart, this line is the
  // one to edit, and the site has to be rebuilt and redeployed for the change
  // to reach anyone.
  'https://basic-shopzilla-similar-daisy.trycloudflare.com':
      'https://klein-drop-mobility-membrane.trycloudflare.com',
};

/// Swaps a retired backend URL for its live replacement.
///
/// Runs on the *normalized* value, and on the value from localStorage as well
/// as the one from `?backend=` — both matter. Someone who scanned the QR once
/// already has the dead hostname persisted, so reopening the plain site later
/// carries no query param to fix and would otherwise stay broken forever.
///
/// Matched case-insensitively: QR encoders fall back to alphanumeric mode for
/// payloads that are entirely uppercase, and some tools uppercase a URL to get
/// there. Hostnames are case-insensitive anyway, so this costs nothing.
///
/// Anything not in the map is returned untouched — this must never become a
/// filter on where the app is allowed to point.
String redirectRetiredBackendUrl(String url) =>
    kRetiredBackendUrls[url.toLowerCase()] ?? url;

/// Strips trailing slashes and surrounding whitespace from a base URL.
///
/// WHY THIS IS NOT A COSMETIC TIDY-UP
/// ----------------------------------
/// The paths below supply their own leading slash, so a base that ends in one
/// produces `https://host//upload` — and that is a *different path*, not a
/// forgiving spelling of the same one. Starlette matches routes literally and
/// answers 404, so every upload and every transcription fails while `/health`,
/// typed by hand in a browser, keeps returning 200 and the backend looks fine.
///
/// It is easy to hit and hard to see. The tunnel URL arrives by copy-paste, a
/// browser address bar shows a bare host with a trailing slash, and the value
/// is then remembered in localStorage — so one bad paste keeps breaking the app
/// on later visits that carry no `?backend=` at all. Normalizing on read fixes
/// those already-stored values too.
String normalizeBackendBaseUrl(String url) {
  var out = url.trim();
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Thai Whisper transcription, used by every voice subtest.
final String kTranscribeEndpoint = '$kBackendBaseUrl/transcribe';

/// Clock-drawing DenseNet. Its response's `predicted_moca_score` must be a JSON
/// integer — `clock.dart` assigns it straight to a Dart `int`.
final String kClockUploadEndpoint = '$kBackendBaseUrl/upload';

/// Multilingual sentence embeddings, used by abstraction scoring. Adding this
/// moved abstraction from an offline pure-Dart rule to a network-dependent one:
/// it now skips rather than scores when the backend is unreachable, the same as
/// every other backend-scored subtest.
final String kSimilarityEndpoint = '$kBackendBaseUrl/similarity';

/// Liveness probe. Nothing calls this yet; it is here so a future pre-flight
/// check does not reintroduce a second spelling of the base URL.
final String kHealthEndpoint = '$kBackendBaseUrl/health';

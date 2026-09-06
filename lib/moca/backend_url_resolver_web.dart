import 'package:web/web.dart' as web;

/// A quick Cloudflare tunnel gets a new hostname every restart, so the
/// published GitHub Pages build can't have it baked in at compile time the
/// way `--dart-define` normally works — that would mean a full rebuild and
/// redeploy every demo session. Instead: share a link with `?backend=` set to
/// today's tunnel URL, and remember it in localStorage so reopening the site
/// afterwards (no query param) still points at it.
const _storageKey = 'moca_backend_base_url';

String resolveBackendBaseUrl(String compiledDefault) {
  final fromQuery = Uri.base.queryParameters['backend'];
  if (fromQuery != null && fromQuery.isNotEmpty) {
    try {
      web.window.localStorage.setItem(_storageKey, fromQuery);
    } catch (_) {
      // localStorage can throw under a blocked/private-mode storage policy;
      // the query param still wins for this page load either way.
    }
    return fromQuery;
  }

  try {
    final remembered = web.window.localStorage.getItem(_storageKey);
    if (remembered != null && remembered.isNotEmpty) return remembered;
  } catch (_) {}

  return compiledDefault;
}

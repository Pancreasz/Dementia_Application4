import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/asr_client.dart';
import 'package:moca_main/moca/backend_config.dart';

void main() {
  test('every endpoint derives from the one base URL', () {
    expect(kTranscribeEndpoint, '$kBackendBaseUrl/transcribe');
    expect(kClockUploadEndpoint, '$kBackendBaseUrl/upload');
    expect(kHealthEndpoint, '$kBackendBaseUrl/health');
  });

  test('the ASR endpoint is not a second spelling of the base URL', () {
    // The whole point of backend_config.dart: moving hosts must not require
    // remembering that asr_client.dart holds its own copy.
    expect(kDefaultAsrEndpoint, kTranscribeEndpoint);
  });

  test('the base URL carries no trailing slash', () {
    // The paths concatenate directly, so a trailing slash silently produces
    // //transcribe.
    expect(kBackendBaseUrl.endsWith('/'), isFalse);
  });

  group('a pasted base URL is normalized, not just documented', () {
    // The test above only ever saw the compiled default, which never had a
    // trailing slash. The value that actually breaks arrives at runtime, from
    // `?backend=` or from localStorage, and on 2026-09-08 one did: every
    // request went to //upload and //transcribe and came back 404 while
    // /health, typed by hand, kept answering 200.
    test('a trailing slash is removed', () {
      expect(normalizeBackendBaseUrl('https://demo.trycloudflare.com/'),
          'https://demo.trycloudflare.com');
    });

    test('so is more than one', () {
      expect(normalizeBackendBaseUrl('https://demo.trycloudflare.com///'),
          'https://demo.trycloudflare.com');
    });

    test('so is whitespace around a copy-pasted link', () {
      expect(normalizeBackendBaseUrl('  https://demo.trycloudflare.com/ \n'),
          'https://demo.trycloudflare.com');
    });

    test('a URL that was already correct is left exactly as it was', () {
      expect(normalizeBackendBaseUrl('http://localhost:8000'),
          'http://localhost:8000');
    });

    test('a path prefix is kept — only the trailing slash goes', () {
      // A backend hosted under a sub-path is a legitimate deployment, and
      // trimming its path would break it.
      expect(normalizeBackendBaseUrl('https://example.net/moca/'),
          'https://example.net/moca');
    });

    test('the endpoints built from a pasted URL have exactly one slash', () {
      final base = normalizeBackendBaseUrl('https://demo.trycloudflare.com/');
      expect('$base/upload', 'https://demo.trycloudflare.com/upload');
      expect('$base/transcribe', 'https://demo.trycloudflare.com/transcribe');
    });
  });

  group('a URL printed on paper outlives the tunnel it names', () {
    // A QR code was printed on 2026-09-09 with ?backend= set to a quick tunnel
    // that has since gone. Paper cannot be reissued and GitHub Pages cannot
    // redirect, so this app is the only thing left that can act on it.
    const dead = 'https://basic-shopzilla-similar-daisy.trycloudflare.com';
    const live = 'https://klein-drop-mobility-membrane.trycloudflare.com';

    test('the printed QR URL resolves to the live tunnel', () {
      expect(redirectRetiredBackendUrl(dead), live);
    });

    test('the live URL is not itself retired', () {
      // Guards the obvious way to break this: adding a new entry whose target
      // is an older key, which would send traffic straight back to a dead host.
      expect(redirectRetiredBackendUrl(live), live);
      for (final target in kRetiredBackendUrls.values) {
        expect(kRetiredBackendUrls.containsKey(target.toLowerCase()), isFalse,
            reason: '$target is both a replacement and a retired URL');
      }
    });

    test('an uppercased scan still matches', () {
      // QR encoders use alphanumeric mode for an all-uppercase payload, and
      // some uppercase the URL to get there. Hostnames are case-insensitive.
      expect(redirectRetiredBackendUrl(dead.toUpperCase()), live);
    });

    test('a trailing slash on the stored value still matches', () {
      // The order in kBackendBaseUrl is normalize-then-redirect precisely so
      // that a value remembered with a slash is not missed.
      expect(redirectRetiredBackendUrl(normalizeBackendBaseUrl('$dead/')), live);
    });

    test('any other backend is passed through untouched', () {
      // This is a replacement table, not an allowlist. A local run and a fresh
      // tunnel must both survive it.
      expect(redirectRetiredBackendUrl('http://localhost:8000'),
          'http://localhost:8000');
      expect(redirectRetiredBackendUrl('https://brand-new.trycloudflare.com'),
          'https://brand-new.trycloudflare.com');
    });

    test('the resolved base URL never points at the retired tunnel', () {
      // The end-to-end guarantee, whatever the value came from.
      expect(kBackendBaseUrl, isNot(contains('basic-shopzilla-similar-daisy')));
    });
  });

  test('the dead Azure deployment is gone from the default', () {
    // moca-flask-container.azurewebsites.net was decommissioned. Pointing at
    // it fails the clock test and all eight voice subtests at once.
    expect(kBackendBaseUrl, isNot(contains('azurewebsites.net')));
  });

  test('the ASR timeout outlasts verbal fluency, whose clip is 60 s', () {
    final client = HttpAsrClient(endpoint: Uri.parse(kTranscribeEndpoint));
    expect(client.timeout.inSeconds, greaterThanOrEqualTo(120));
  });
}

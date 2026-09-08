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

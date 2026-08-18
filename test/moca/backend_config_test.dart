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

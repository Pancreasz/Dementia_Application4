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
/// No trailing slash: the paths below concatenate directly.
const String kBackendBaseUrl = String.fromEnvironment(
  'MOCA_BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// Thai Whisper transcription, used by every voice subtest.
const String kTranscribeEndpoint = '$kBackendBaseUrl/transcribe';

/// Clock-drawing DenseNet. Its response's `predicted_moca_score` must be a JSON
/// integer — `clock.dart` assigns it straight to a Dart `int`.
const String kClockUploadEndpoint = '$kBackendBaseUrl/upload';

/// Liveness probe. Nothing calls this yet; it is here so a future pre-flight
/// check does not reintroduce a second spelling of the base URL.
const String kHealthEndpoint = '$kBackendBaseUrl/health';

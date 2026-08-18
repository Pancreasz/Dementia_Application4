# Digital MoCA

A Thai MoCA (Montreal Cognitive Assessment) cognitive-screening app, built in
Flutter and run **in a web browser** (Chrome). The patient draws, taps, types
and speaks; the app scores automatically. Clock drawing and all voice
subtests are scored by a local FastAPI backend, so the backend must be
running before you use the app.

## MoCA subtest coverage

29 of 30 points are implemented. Cube copy is administered on paper. Voice
scoring and clock scoring both require the backend below. See
[design_docs/CONTENT-STATUS.md](design_docs/CONTENT-STATUS.md) for the
`/transcribe` contract, the test content that must be changed in pairs, and
known limitations.

## Running the web app in Chrome

### 1. Install Flutter

Flutter is not expected to be on `PATH`. Add it for the current shell:

```powershell
$env:PATH = "C:\Users\<you>\dev\flutter\bin;$env:PATH"
```

(adjust the path to wherever you installed the Flutter SDK). Confirm it works:

```powershell
flutter doctor
```

Then fetch this project's Dart packages from the repo root:

```powershell
flutter pub get
```

### 2. Start the backend first

The app does not bundle or fall back for clock/voice scoring — it calls out
to a live backend at `http://localhost:8000`. See
[**Backend setup**](#backend-setup) below to install its environment, then
start it (from `backend/`):

```powershell
..\.venv\Scripts\python.exe -m uvicorn app:app --host 0.0.0.0 --port 8000
```

Leave that running in its own terminal.

### 3. Run the Flutter app in Chrome

From the repo root, with the backend already running:

```powershell
flutter run -d chrome
```

This builds a debug web build and opens it in Chrome with hot reload. The
microphone requires a "secure context" (https, or localhost as used here), so
`flutter run -d chrome` satisfies that automatically.

To point the app at a different backend host instead of
`http://localhost:8000` (e.g. a deployed backend), pass it as a
`--dart-define` rather than editing code:

```powershell
flutter run -d chrome --dart-define=MOCA_BACKEND_BASE_URL=https://example.net
```

### Running the tests

```powershell
flutter test                     # ~219 tests
flutter analyze                  # static analysis
```

## Backend setup

The backend lives in `backend/`. Full detail — CORS, latency numbers, model
validation — is in [`backend/README.md`](backend/README.md); the short
version to get it running from a fresh clone (Windows, Python 3.14):

```bash
cd backend
python -m venv ../.venv
../.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
../.venv/Scripts/python.exe scripts/restore_weights.py
```

That much is enough to run `/upload` (clock scoring) and the backend's own
test suite. `/transcribe` (all voice subtests) additionally needs the ASR
model — a separate, heavier download (~1.6 GB → ~800 MB int8 after
conversion):

```bash
../.venv/Scripts/python.exe -m pip install -r requirements-convert.txt
../.venv/Scripts/python.exe scripts/convert_model.py
```

Then start it as shown in step 2 above. The venv is expected at
`Dementia_Application4/.venv`, one level *above* `backend/` — every backend
command is written as `../.venv/...` for that reason.

### Verify the backend is healthy

```bash
curl http://localhost:8000/health
```

`/health` reports `loading` until the models finish loading (model load can
take 30–100+ s the first time), then `ok`.

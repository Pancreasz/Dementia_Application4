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

## After the test

The last subtest hands off to a **per-domain breakdown**
(`lib/pages/analysis.dart`), and that page continues to the score. Each MoCA
domain gets one of three levels, taken from the points scored in it **and from
nothing else** — the stored measurements appear underneath as description and
never move anyone into a worse level. Measurements that are not recorded at all
say so on the page rather than being left blank. From the score page there is
also an **activities** page (`lib/pages/activities.dart`), worded as activities
that *engage* a domain rather than improve a score, and deliberately excluding
anything resembling a MoCA subtest — practising them would contaminate the
patient's own follow-up screening.

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
flutter test                     # ~400 tests
flutter analyze                  # static analysis
```

Backend tests, from `backend/`:

```bash
../.venv/Scripts/python.exe -m pytest              # fast; fakes every model
../.venv/Scripts/python.exe -m pytest -m slowmodel # loads the real embedding model
```

`slowmodel` is deselected by default. Those tests download ~470 MB and take
~50 s to load, and they are the only check that the embedding model still
ranks abstract abstraction answers above concrete ones — run them after
changing the model or the accepted-term lists.

## Publishing to GitHub Pages

`docs/` **is** the published site — GitHub Pages serves it straight from that
folder on `main`. It is entirely build output; nothing in it is hand-written, so
it is safe to wipe and regenerate. Nothing rebuilds it automatically: a change
to `lib/` is not live until you run this, which is the one way to ship a backend
fix and silently leave the frontend that uses it a month behind.

**Run this in PowerShell, not Git Bash** — see the warning below.

```powershell
flutter build web --release --base-href /Dementia_Application4/
Remove-Item -Recurse -Force docs\*
Copy-Item -Recurse -Force build\web\* docs\
```

Then check the base href actually landed before committing:

```powershell
Select-String -Path docs\index.html -Pattern '<base href'
```

It must print `<base href="/Dementia_Application4/">`. If it says `/` instead,
the site loads a blank page on Pages — every asset resolves against the wrong
root. Then:

```powershell
git add docs
git commit -m "Rebuild web app"
git push
```

### Why PowerShell and not Git Bash

Git Bash runs under MSYS, which rewrites any argument that looks like a Unix
absolute path into a Windows one. `--base-href /Dementia_Application4/` becomes
`--base-href C:/Program Files/Git/Dementia_Application4/`. The build **exits 0**
and looks like it worked; the base href is simply wrong. If you must use bash,
prefix the command with `MSYS_NO_PATHCONV=1`.

### After publishing

The browser caches the old build in a service worker, so the new one does not
appear on a normal reload. **Hard-refresh** (Ctrl+Shift+R), and on a phone, use
a private tab to be sure.

The published site talks to whatever backend you point it at. A Cloudflare quick
tunnel gets a new hostname on every restart, so pass it in the link rather than
rebuilding:

```
https://<user>.github.io/Dementia_Application4/?backend=https://today-tunnel.trycloudflare.com
```

**No trailing slash on that URL.** It is remembered in localStorage, so a bad
one keeps breaking later visits that carry no `?backend=` at all.

### When a shared link outlives its tunnel

A link that has left your hands — printed on a QR code, sent in an email —
cannot be corrected at the source, and GitHub Pages serves static files so it
cannot redirect. `kRetiredBackendUrls` in
[`lib/moca/backend_config.dart`](lib/moca/backend_config.dart) maps a retired
hostname to the current one; the app substitutes it on load, for the remembered
localStorage value as well as for `?backend=`. **A QR code printed 2026-09-09
depends on this.** If that PC restarts and the tunnel changes, edit the map and
republish `docs/` — the printed sheet keeps working, but only because of that
line.

Every entry is a standing promise to keep one machine reachable. Add one only
for a link genuinely out of reach, never in place of sharing a current link, and
delete it once the paper is out of circulation.

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
test suite. **`GET /health` is the check** — it reports each of the four models
separately, and on a fresh clone the two ASR entries are expected to say
`no model directory at …` until their downloads are done. Every model's failure
detail quotes the command that fixes it; if the clock model reports an
*incomplete restore*, re-run `scripts/restore_weights.py`. `/similarity` (abstraction scoring) needs a multilingual
sentence-transformer, which `pip install -r requirements.txt` brings in and
which downloads itself (~470 MB) on first startup — no separate step.

`/transcribe` (all voice subtests) additionally needs the ASR model,
`scb10x/typhoon-whisper-large-v3` — a separate, much heavier download
(~5.8 GB → ~3.1 GB float16 after conversion):

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
take 30–100+ s the first time), then `ok`. It covers four models now —
`clock`, `asr` (Thai), `asr_en` (English) and `similarity` — and reports each
separately, so a single failed load is diagnosable from the body rather than
only visible as an aggregate `error`.

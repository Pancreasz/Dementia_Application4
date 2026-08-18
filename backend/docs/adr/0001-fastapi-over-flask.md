# Serve the MoCA backend with FastAPI, not Flask

The lost original backend was a Flask service (its deployed name,
`moca-flask-container`, is the only trace left), and the voice-subtests design
doc assumed the `/transcribe` endpoint would be "a transliteration into Flask".
We are instead building on **FastAPI + uvicorn**.

**Why:** nothing in the repo depends on Flask; `fastapi` and `uvicorn` are the
web stack the handout standardises on; FastAPI's async lifespan expresses the
required "load the model on a background thread so `/health` answers
immediately" pattern cleanly; and the Flutter client (`clock.dart`,
`asr_client.dart`) is framework-agnostic — it sends multipart and reads JSON, so
the swap is invisible to it.

**Considered and rejected:** staying on Flask to match the design doc and the old
service. Rejected because the only thing that carried over from the old service
was its name, and matching a name is not a reason to pick a framework.

_Status: accepted (2026-08-18). Reverses the Flask assumption in
design_docs/superpowers/specs/2026-08-17-voice-subtests-design.md._

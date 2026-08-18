"""Route-level contract tests. All model work is faked (see conftest.py)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app as app_module
from asr import LoadState, Segment, Transcription
from conftest import FakeAsr, FakeClock


def make_client(clock=None, asr=None, monkeypatch=None):
    monkeypatch.setattr(app_module, "clock_model", clock or FakeClock())
    monkeypatch.setattr(app_module, "asr_model", asr or FakeAsr())
    return TestClient(app_module.app)


# --------------------------------------------------------------------------
# /upload — the three "crash the app" cases from clock.dart
# --------------------------------------------------------------------------

def test_upload_types_are_exactly_int_and_strings(monkeypatch):
    client = make_client(clock=FakeClock(score=2), monkeypatch=monkeypatch)
    resp = client.post("/upload", files={"file": ("d.png", b"pngbytes", "image/png")})
    assert resp.status_code == 200
    body = resp.json()

    # predicted_moca_score MUST be a JSON int, not 2.0 and not "2".
    assert isinstance(body["predicted_moca_score"], int)
    assert not isinstance(body["predicted_moca_score"], bool)
    assert body["predicted_moca_score"] == 2

    # message and filename MUST be strings.
    assert isinstance(body["message"], str)
    assert isinstance(body["filename"], str)
    assert body["filename"] == "d.png"


@pytest.mark.parametrize("score", [0, 1, 2, 3])
def test_upload_all_valid_scores_pass_through_as_int(monkeypatch, score):
    client = make_client(clock=FakeClock(score=score), monkeypatch=monkeypatch)
    resp = client.post("/upload", files={"file": ("d.png", b"x", "image/png")})
    assert resp.status_code == 200
    assert resp.json()["predicted_moca_score"] == score


def test_upload_requires_a_file_part(monkeypatch):
    # A part with no filename is not an UploadFile; FastAPI rejects it as 422,
    # not 500. The real client always sends a filename, so this is just the
    # guard that a malformed request never reaches inference.
    client = make_client(clock=FakeClock(score=1), monkeypatch=monkeypatch)
    resp = client.post("/upload", files={"file": ("", b"x", "image/png")})
    assert resp.status_code == 422


def test_upload_bad_image_is_4xx_not_500(monkeypatch):
    client = make_client(clock=FakeClock(raises=ValueError("bad")), monkeypatch=monkeypatch)
    resp = client.post("/upload", files={"file": ("d.png", b"notanimage", "image/png")})
    assert resp.status_code == 400


def test_upload_empty_body_is_4xx(monkeypatch):
    client = make_client(monkeypatch=monkeypatch)
    resp = client.post("/upload", files={"file": ("d.png", b"", "image/png")})
    assert resp.status_code == 400


def test_upload_model_unavailable_is_503_with_short_body(monkeypatch):
    client = make_client(
        clock=FakeClock(raises=RuntimeError("weights missing at /x")),
        monkeypatch=monkeypatch,
    )
    resp = client.post("/upload", files={"file": ("d.png", b"x", "image/png")})
    assert resp.status_code == 503
    # Body stays short and free of the internal path.
    assert "/x" not in resp.text


# --------------------------------------------------------------------------
# /transcribe
# --------------------------------------------------------------------------

def test_transcribe_returns_text_and_segment_shape(monkeypatch):
    result = Transcription(
        text="สองสี่เจ็ด",
        segments=[Segment(start=0.0, end=0.5, text="สอง")],
    )
    client = make_client(asr=FakeAsr(result=result), monkeypatch=monkeypatch)
    resp = client.post(
        "/transcribe",
        files={"file": ("r.wav", b"wavbytes", "audio/wav")},
        data={"language": "th"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["text"] == "สองสี่เจ็ด"
    assert isinstance(body["segments"], list)
    seg = body["segments"][0]
    assert set(seg) == {"start", "end", "text"}
    assert isinstance(seg["start"], float) and isinstance(seg["end"], float)
    assert seg["text"] == "สอง"


def test_transcribe_503_while_loading_not_200_empty(monkeypatch):
    client = make_client(
        asr=FakeAsr(state=LoadState.LOADING, detail="model not loaded"),
        monkeypatch=monkeypatch,
    )
    resp = client.post(
        "/transcribe",
        files={"file": ("r.wav", b"x", "audio/wav")},
        data={"language": "th"},
    )
    assert resp.status_code == 503
    assert resp.json()["detail"] == "model not loaded"


def test_transcribe_503_when_load_errored(monkeypatch):
    client = make_client(
        asr=FakeAsr(state=LoadState.ERROR, detail="SSL_CERT_FILE points at a missing file"),
        monkeypatch=monkeypatch,
    )
    resp = client.post(
        "/transcribe",
        files={"file": ("r.wav", b"x", "audio/wav")},
        data={"language": "th"},
    )
    assert resp.status_code == 503
    assert "SSL_CERT_FILE" in resp.json()["detail"]


def test_transcribe_decode_failure_is_4xx(monkeypatch):
    client = make_client(
        asr=FakeAsr(raises=RuntimeError("no audio stream")),
        monkeypatch=monkeypatch,
    )
    resp = client.post(
        "/transcribe",
        files={"file": ("r.wav", b"garbage", "audio/wav")},
        data={"language": "th"},
    )
    assert resp.status_code == 400


# --------------------------------------------------------------------------
# /health
# --------------------------------------------------------------------------

def test_health_answers_immediately_while_loading(monkeypatch):
    client = make_client(
        clock=FakeClock(state=LoadState.LOADING, detail="model not loaded"),
        asr=FakeAsr(state=LoadState.LOADING, detail="model not loaded"),
        monkeypatch=monkeypatch,
    )
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "loading"


def test_health_reports_error_with_diagnosable_detail(monkeypatch):
    client = make_client(
        asr=FakeAsr(state=LoadState.ERROR, detail="conda broke SSL_CERT_FILE"),
        monkeypatch=monkeypatch,
    )
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "error"
    assert "SSL_CERT_FILE" in body["detail"]


def test_health_ready_when_both_ready(monkeypatch):
    client = make_client(monkeypatch=monkeypatch)
    resp = client.get("/health")
    assert resp.json()["status"] == "ready"

"""Unit tests for asr.py load-state machine and failure diagnostics.

A fake `faster_whisper` module is injected so these never import ctranslate2 or
download a model.
"""

from __future__ import annotations

import sys
import types

from asr import AsrModel, LoadState, Segment, Transcription, describe_load_failure


def _install_fake_faster_whisper(monkeypatch, model_factory):
    mod = types.ModuleType("faster_whisper")
    mod.WhisperModel = model_factory
    monkeypatch.setitem(sys.modules, "faster_whisper", mod)


# --------------------------------------------------------------------------
# describe_load_failure — the conda SSL_CERT_FILE gotcha
# --------------------------------------------------------------------------

def test_describe_load_failure_names_broken_ssl_cert_file(monkeypatch):
    monkeypatch.setenv("SSL_CERT_FILE", r"C:\does\not\exist\cacert.pem")
    detail = describe_load_failure(FileNotFoundError("nope"))
    assert "SSL_CERT_FILE" in detail
    assert "conda" in detail.lower()


def test_describe_load_failure_generic_for_other_errors(monkeypatch):
    monkeypatch.delenv("SSL_CERT_FILE", raising=False)
    detail = describe_load_failure(RuntimeError("boom"))
    assert "model load failed" in detail
    assert "SSL_CERT_FILE" not in detail


# --------------------------------------------------------------------------
# AsrModel load state machine
# --------------------------------------------------------------------------

def test_starts_in_loading_without_touching_the_model():
    m = AsrModel()
    assert m.state == LoadState.LOADING
    assert not m.is_ready


def test_load_success_transitions_to_ready(monkeypatch):
    _install_fake_faster_whisper(monkeypatch, lambda *a, **k: object())
    m = AsrModel()
    m._load()  # synchronous, no thread
    assert m.state == LoadState.READY
    assert m.is_ready


def test_load_failure_transitions_to_error_with_detail(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("ct2 missing")

    _install_fake_faster_whisper(monkeypatch, boom)
    m = AsrModel()
    m._load()
    assert m.state == LoadState.ERROR
    assert "ct2 missing" in m.detail


# --------------------------------------------------------------------------
# transcribe keeps segments
# --------------------------------------------------------------------------

def test_transcribe_keeps_faster_whisper_segments():
    seg1 = types.SimpleNamespace(start=0.0, end=0.5, text="สอง")
    seg2 = types.SimpleNamespace(start=0.6, end=1.1, text="สี่")

    class StubModel:
        def transcribe(self, audio, language="th"):
            return iter([seg1, seg2]), types.SimpleNamespace(language=language)

    m = AsrModel()
    m._model = StubModel()
    result = m.transcribe(b"audio", language="th")

    assert isinstance(result, Transcription)
    assert result.text == "สองสี่"  # joined + stripped
    assert len(result.segments) == 2
    assert isinstance(result.segments[0], Segment)
    assert result.segments[1].text == "สี่"

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
        def transcribe(self, audio, language="th", **kwargs):
            return iter([seg1, seg2]), types.SimpleNamespace(language=language)

    m = AsrModel()
    m._model = StubModel()
    result = m.transcribe(b"audio", language="th")

    assert isinstance(result, Transcription)
    assert result.text == "สองสี่"  # joined + stripped
    assert len(result.segments) == 2
    assert isinstance(result.segments[0], Segment)
    assert result.segments[1].text == "สี่"


def test_transcribe_pins_the_decoding_options_that_fixed_digit_span():
    """Both options are load-bearing and neither is faster-whisper's default.

    temperature: the default is a fallback ladder of six temperatures, and a
    clip the model hallucinates on is re-decoded at every step. That alone made
    a 7.8-second digit-span clip take 144-174 s.

    repetition_penalty: without it the model emitted the digit sequence four
    times over for a clip containing it once, and scoreDigitSpan compares for
    exact equality — so a correct patient scored 0.

    Dropping either silently restores a bug that looks like a patient deficit,
    which is why this asserts on the call rather than on the transcript.
    """
    seen = {}

    class RecordingModel:
        def transcribe(self, audio, language="th", **kwargs):
            seen.update(kwargs)
            return iter([]), types.SimpleNamespace(language=language)

    m = AsrModel(temperature=0, repetition_penalty=1.10)
    m._model = RecordingModel()
    m.transcribe(b"audio")

    assert seen["temperature"] == 0
    assert seen["repetition_penalty"] == 1.10


def test_decoding_options_are_overridable_without_editing_code():
    # The verbal-fluency risk (a Thai letter-fluency answer legitimately
    # repeats a prefix) needs real audio to settle, so these have to be
    # tunable in the field.
    seen = {}

    class RecordingModel:
        def transcribe(self, audio, language="th", **kwargs):
            seen.update(kwargs)
            return iter([]), types.SimpleNamespace(language=language)

    m = AsrModel(temperature=0.4, repetition_penalty=1.0)
    m._model = RecordingModel()
    m.transcribe(b"audio")

    assert seen["temperature"] == 0.4
    assert seen["repetition_penalty"] == 1.0

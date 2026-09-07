"""Tests for embeddings.py and the /similarity route.

Split into two halves:

  - Everything above `TestLiveModel` runs offline with fakes and plain lists.
  - `TestLiveModel` downloads and runs the REAL multilingual model. It is
    deselected by default (`-m "not slowmodel"` in pytest.ini) because it costs
    a 470 MB download and ~50 s of load. Run it deliberately:

        pytest -m slowmodel

That split matters. The Dart unit tests in test/scoring/abstraction_test.dart
assert the scoring rule against similarity numbers PASTED IN from a measurement
run — they cannot notice if the model starts ranking answers differently. The
live tests below are the ones that would catch that, which is why they exist
even though nothing runs them automatically.
"""

from __future__ import annotations

import math

import pytest
from fastapi.testclient import TestClient

import app as app_module
import embeddings
from asr import LoadState
from conftest import FakeAsr, FakeClock, FakeSimilarity


def make_client(similarity=None, monkeypatch=None):
    monkeypatch.setattr(app_module, "clock_model", FakeClock())
    monkeypatch.setattr(app_module, "asr_model", FakeAsr())
    monkeypatch.setattr(
        app_module, "similarity_model", similarity or FakeSimilarity()
    )
    return TestClient(app_module.app)


# --------------------------------------------------------------------------
# cosine — pure maths, no model
# --------------------------------------------------------------------------

def test_cosine_of_identical_vectors_is_one_within_float_error():
    # Note "within float error", not "exactly". Summing products of floats and
    # dividing by two square roots lands either side of 1.0 — measured
    # 0.9999999999999998 for this input. The clamp bounds the result to
    # [-1, 1]; it does not, and cannot, make it exact.
    assert math.isclose(
        embeddings.cosine([0.3, 0.4, 0.5], [0.3, 0.4, 0.5]), 1.0, rel_tol=1e-12
    )


def test_cosine_of_orthogonal_vectors_is_zero():
    assert embeddings.cosine([1.0, 0.0], [0.0, 1.0]) == 0.0


def test_cosine_of_opposite_vectors_is_minus_one():
    assert embeddings.cosine([1.0, 0.0], [-1.0, 0.0]) == -1.0


def test_cosine_stays_inside_the_unit_range():
    # Long vectors accumulate float error; the clamp has to hold regardless.
    a = [0.1] * 512
    b = [0.1] * 512
    assert -1.0 <= embeddings.cosine(a, b) <= 1.0


def test_cosine_with_a_zero_vector_is_zero_not_an_exception():
    # A zero vector has no direction. An empty answer is a real thing a patient
    # does and must score 0, not 500 the request.
    assert embeddings.cosine([0.0, 0.0], [1.0, 1.0]) == 0.0
    assert embeddings.cosine([1.0, 1.0], [0.0, 0.0]) == 0.0


def test_cosine_is_scale_invariant():
    assert math.isclose(
        embeddings.cosine([1.0, 2.0], [2.0, 4.0]), 1.0, rel_tol=1e-9
    )


# --------------------------------------------------------------------------
# SimilarityModel — construction and load state, still no real model
# --------------------------------------------------------------------------

def test_constructing_the_model_does_not_load_anything():
    # Same rule as AsrModel: importing/constructing in tests must never touch
    # weights or reach the network.
    model = embeddings.SimilarityModel()
    assert model.state == LoadState.LOADING
    assert not model.is_ready


def test_a_failed_load_is_reported_not_raised():
    # /health has to be able to DIAGNOSE a bad load, so the failure lands in
    # `detail` rather than taking the process down.
    model = embeddings.SimilarityModel(model_name="definitely/not-a-real-model")
    model.start_loading().join(timeout=60)
    assert model.state == LoadState.ERROR
    assert model.detail  # non-empty, and describes the failure
    assert not model.is_ready


def test_encode_before_ready_raises_rather_than_returning_garbage():
    model = embeddings.SimilarityModel()
    with pytest.raises(RuntimeError):
        model.encode(["anything"])


def test_similarities_with_no_terms_is_empty():
    model = embeddings.SimilarityModel()
    # Returns before touching the model, so this is safe while LOADING.
    assert model.similarities("answer", []) == {}


# --------------------------------------------------------------------------
# /similarity route contract
# --------------------------------------------------------------------------

def test_similarity_returns_every_term_not_just_the_best(monkeypatch):
    # The full map is what makes "correct category, low similarity" auditable.
    fake = FakeSimilarity(scores={"vehicle": 0.8, "transport": 0.3})
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    resp = client.post(
        "/similarity", json={"answer": "a bus", "terms": ["vehicle", "transport"]}
    )
    assert resp.status_code == 200
    assert resp.json()["similarities"] == {"vehicle": 0.8, "transport": 0.3}


def test_similarity_reports_the_best_term_and_score(monkeypatch):
    fake = FakeSimilarity(scores={"vehicle": 0.2, "transport": 0.9})
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    body = client.post(
        "/similarity", json={"answer": "x", "terms": ["vehicle", "transport"]}
    ).json()
    assert body["best_term"] == "transport"
    assert body["best_score"] == 0.9


def test_similarity_echoes_the_model_name(monkeypatch):
    # Changing the model changes every number. Without this, old and new scores
    # are indistinguishable on review.
    fake = FakeSimilarity(scores={"vehicle": 0.5}, model_name="minilm-v2")
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    body = client.post("/similarity", json={"answer": "x", "terms": ["vehicle"]}).json()
    assert body["model"] == "minilm-v2"


def test_similarity_passes_the_answer_and_terms_through_unchanged(monkeypatch):
    fake = FakeSimilarity(scores={"ยานพาหนะ": 0.9})
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    client.post(
        "/similarity", json={"answer": "เป็นยานพาหนะ", "terms": ["ยานพาหนะ", "รถไฟ"]}
    )
    assert fake.last_answer == "เป็นยานพาหนะ"
    assert fake.last_terms == ["ยานพาหนะ", "รถไฟ"]


def test_similarity_is_503_while_the_model_loads(monkeypatch):
    # Mirrors /transcribe. A 200 with all-zero similarities would be scored as
    # the patient having answered wrongly.
    fake = FakeSimilarity(state=LoadState.LOADING, detail="model not loaded")
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    resp = client.post("/similarity", json={"answer": "x", "terms": ["vehicle"]})
    assert resp.status_code == 503


def test_similarity_is_503_when_the_model_failed_to_load(monkeypatch):
    fake = FakeSimilarity(state=LoadState.ERROR, detail="weights missing")
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    resp = client.post("/similarity", json={"answer": "x", "terms": ["vehicle"]})
    assert resp.status_code == 503
    # The load failure is surfaced so it can be diagnosed, not swallowed.
    assert "weights missing" in resp.json()["detail"]


def test_similarity_with_no_terms_is_400_not_a_silent_zero(monkeypatch):
    # An empty term list is a caller bug (a subtest id with no registered
    # terms), not a patient finding.
    client = make_client(monkeypatch=monkeypatch)
    resp = client.post("/similarity", json={"answer": "x", "terms": []})
    assert resp.status_code == 400


def test_similarity_encode_failure_is_4xx_not_500(monkeypatch):
    fake = FakeSimilarity(raises=ValueError("bad input"))
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    resp = client.post("/similarity", json={"answer": "x", "terms": ["vehicle"]})
    assert resp.status_code == 400


def test_similarity_rejects_a_malformed_body(monkeypatch):
    client = make_client(monkeypatch=monkeypatch)
    assert client.post("/similarity", json={"answer": "x"}).status_code == 422
    assert client.post("/similarity", json={"terms": ["a"]}).status_code == 422


# --------------------------------------------------------------------------
# /health now covers three models
# --------------------------------------------------------------------------

def test_health_reports_the_similarity_model(monkeypatch):
    client = make_client(monkeypatch=monkeypatch)
    body = client.get("/health").json()
    assert body["models"]["similarity"]["status"] == "ready"


def test_health_is_loading_when_only_the_embedding_model_is(monkeypatch):
    fake = FakeSimilarity(state=LoadState.LOADING, detail="model not loaded")
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    body = client.get("/health").json()
    assert body["status"] == "loading"


def test_health_is_error_when_only_the_embedding_model_failed(monkeypatch):
    fake = FakeSimilarity(state=LoadState.ERROR, detail="boom")
    client = make_client(similarity=fake, monkeypatch=monkeypatch)
    resp = client.get("/health")
    # 200 always: /health must be reachable to diagnose a bad load.
    assert resp.status_code == 200
    assert resp.json()["status"] == "error"


# --------------------------------------------------------------------------
# The real model. Deselected by default — see the module docstring.
# --------------------------------------------------------------------------

TERMS_TH_1 = ["ยานพาหนะ", "พาหนะ", "ขนส่ง", "เดินทาง"]
STIMULI_TH_1 = ["รถไฟ", "จักรยาน"]
TERMS_EN_1 = [
    "vehicle",
    "vehicles",
    "transportation",
    "transport",
    "travel",
    "getting around",
]
STIMULI_EN_1 = ["train", "bicycle"]


@pytest.mark.slowmodel
class TestLiveModel:
    """Checks the real model still ranks abstraction answers as measured.

    These assert ORDERINGS and SEPARATIONS, not exact values. A model update is
    allowed to move every number; it is not allowed to rank a concrete answer
    above an abstract one.
    """

    @pytest.fixture(scope="class")
    def model(self):
        m = embeddings.SimilarityModel()
        m.start_loading().join(timeout=900)
        assert m.state == LoadState.READY, m.detail
        return m

    @staticmethod
    def _best(model, answer, terms):
        return max(model.similarities(answer, terms).values())

    def test_the_category_anchor_beats_the_stimulus_anchor(self, model):
        """The central design claim, in one test.

        Scoring against the stimulus words inverts the clinical logic: the
        WORST possible answer (repeating the question back) lands nearest the
        stimuli, while the correct category answer lands further away.
        """
        echo = "รถไฟกับจักรยาน"          # scores 0 in the paper instrument
        correct = "เป็นยานพาหนะ"          # scores 1

        # Against the category terms, the correct answer wins — as it must.
        assert self._best(model, correct, TERMS_TH_1) > self._best(
            model, echo, TERMS_TH_1
        )
        # Against the stimulus words, the ordering flips. This is the trap.
        assert self._best(model, echo, STIMULI_TH_1) > self._best(
            model, correct, STIMULI_TH_1
        )

    @pytest.mark.parametrize(
        "abstract,concrete",
        [
            ("เป็นยานพาหนะ", "มีล้อทั้งคู่"),
            ("ใช้เดินทาง", "ทำจากเหล็ก"),
            ("เป็นพาหนะที่มีล้อ", "ขี่ได้ทั้งคู่"),
        ],
    )
    def test_thai_abstract_answers_outrank_concrete_ones(
        self, model, abstract, concrete
    ):
        assert self._best(model, abstract, TERMS_TH_1) > self._best(
            model, concrete, TERMS_TH_1
        )

    @pytest.mark.parametrize(
        "abstract,concrete",
        [
            ("they are both vehicles", "they both have wheels"),
            ("a means of transport", "they are made of metal"),
            ("you use them to travel", "you ride them"),
        ],
    )
    def test_english_abstract_answers_outrank_concrete_ones(
        self, model, abstract, concrete
    ):
        assert self._best(model, abstract, TERMS_EN_1) > self._best(
            model, concrete, TERMS_EN_1
        )

    @pytest.mark.parametrize(
        "echo,terms,stimuli",
        [
            ("รถไฟกับจักรยาน", TERMS_TH_1, STIMULI_TH_1),
            ("a train and a bicycle", TERMS_EN_1, STIMULI_EN_1),
        ],
    )
    def test_the_stimulus_echo_guard_still_fires(self, model, echo, terms, stimuli):
        # The guard is `best_stimulus >= best_category`. If this stops holding,
        # answers that restate the question start scoring points.
        assert self._best(model, echo, stimuli) >= self._best(model, echo, terms)

    def test_the_empty_string_does_not_embed_to_zero(self, model):
        """Why scoreAbstractionFromSimilarities short-circuits before embedding.

        If this ever DOES return ~0, the short-circuit is still correct — it is
        just no longer load-bearing. If it keeps returning ~0.45, removing the
        short-circuit would score silence on the model's opinion of nothing.
        """
        assert self._best(model, "", TERMS_EN_1) > 0.2

    def test_the_english_verb_forms_still_earn_their_place(self, model):
        # Documented in abstraction.dart: without 'travel'/'getting around' the
        # correct answer "both are used for getting around" scored 0.193,
        # below two wrong answers.
        nouns_only = ["vehicle", "vehicles", "transportation", "transport"]
        answer = "both are used for getting around"
        assert self._best(model, answer, TERMS_EN_1) > self._best(
            model, answer, nouns_only
        )

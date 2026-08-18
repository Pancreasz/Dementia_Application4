# MoCA Backend

The HTTP service that scores the two things the Flutter MoCA app cannot do
on-device: a clock-drawing image (`/upload`) and Thai speech (`/transcribe`).
It lives inside the app repo so the HTTP contract is versioned with its client.

## Language

**Clock score**:
The integer 0–3 the DenseNet assigns to a clock drawing. It *equals* the model's
output class index (class 0 = score 0), so "clock score" and "class index" are
the same number. Carried on the wire as `predicted_moca_score`.
_Avoid_: rating, grade, prediction (ambiguous).

**Segment**:
One span of transcript from faster-whisper — `{start, end, text}` — delimited by
the speaker's own acoustic pauses, not by spelling. Verbal Fluency scores by
counting *distinct* segments, because Thai has no spaces and the recognizer's
spacing is arbitrary. Never discard or join them away.
_Avoid_: word, token (both imply orthographic splitting, which is exactly what
segments exist to avoid).

**Transcript**:
The full utterance text — every segment's text concatenated. The `text` field of
a `/transcribe` response. The client throws if it is missing, because an empty
transcript would be scored as the patient having said nothing.
_Avoid_: transcription (that is the act, not the result).

**Load state**:
Where a model is in its background startup: `loading`, `ready`, or `error`. A
model is queried only when `ready`; `/transcribe` answers 503 otherwise, and
`error` carries a diagnosable detail rather than a bare failure.
_Avoid_: status (overloaded — reserve it for the `/health` aggregate).

**Skip vs. score-of-zero** (shared with the Flutter scoring context):
A score of 0 asserts the patient *failed*; a skip asserts the subtest was
*never administered* (e.g. the backend was down). They must never collapse into
each other — a network timeout recorded as 0 is a fabricated clinical finding.

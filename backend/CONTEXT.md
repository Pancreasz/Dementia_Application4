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
the speaker's own acoustic pauses, not by spelling. `/transcribe` must return
them; never discard or join them away.

Verbal Fluency once scored by counting distinct *segments*, on the reasoning
that Thai has no spaces and the speaker's pauses were the only trustworthy
boundary. That was wrong in practice: faster-whisper returns *phrases*, so a
whole 60-second answer came back as one segment and a good patient scored 0.
The scorer now counts distinct whitespace-separated tokens across all segments
(`lib/scoring/verbal_fluency.dart`). Segments still matter — they are what the
tokens are drawn from — but they are no longer the unit of the count.

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

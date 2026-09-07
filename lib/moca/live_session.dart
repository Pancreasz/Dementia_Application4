import '../pages/score.dart' as globals;
import '../scoring/subtest_outcome.dart';
import 'event_trace.dart';
import 'session_record.dart';
import 'session_store.dart';

/// The session currently being administered, and the thing that writes it down.
///
/// WHY THIS SITS BESIDE THE GLOBALS RATHER THAN REPLACING THEM
/// ----------------------------------------------------------
/// `lib/pages/score.dart` holds the live scores in module-level globals, and
/// six pages read them directly. Replacing that with injected state is a large,
/// risky refactor of every page in the app, and it is not what makes the data
/// survive a closed tab — persisting is. So this class mirrors the globals into
/// a [SessionRecord] and saves, and the pages keep reading what they always
/// read. The globals stay the live working copy; this is the durable one.
///
/// That leaves one real hazard, named here because it is invisible otherwise:
/// the two copies can drift if a page writes a global and nothing calls
/// [syncFromGlobals]. [recordOutcome] and [recordScores] both sync before
/// saving, so any path that goes through them is safe; a page that sets a
/// global and navigates away without either is not.
class LiveSession {
  static LiveSession? _current;

  final SessionStore _store;
  SessionRecord _record;

  LiveSession._(this._record, this._store);

  /// The session in progress. Starting one is explicit — see [start] and
  /// [resumeOrStart] — so that merely reading this can never silently create a
  /// session and make a stray page look like an assessment.
  static LiveSession? get current => _current;

  SessionRecord get record => _record;

  /// Where subtests append raw events. Handed out directly so a caller can
  /// record without going through this class for every event.
  TraceLog get trace => _record.trace;

  /// Begins a new session and writes it immediately, so a session that is
  /// abandoned after one subtest still leaves a record.
  static Future<LiveSession> start({SessionStore? store, DateTime? now}) async {
    final session = LiveSession._(
      SessionRecord.startNow(now: now),
      store ?? SessionStore(),
    );
    _current = session;
    session.trace.add(sessionScope, TraceEventType.started);
    await session._save();
    return session;
  }

  /// Picks up an unfinished session if one is on disk, otherwise starts fresh.
  ///
  /// The tab-close case from the README's limitations list. Restores the
  /// globals too, so the pages that read them see the resumed scores rather
  /// than zeros.
  static Future<LiveSession> resumeOrStart({SessionStore? store}) async {
    final s = store ?? SessionStore();
    final existing = await s.loadResumable();
    if (existing == null) return start(store: s);

    final session = LiveSession._(existing, s);
    _current = session;
    session._writeGlobals();
    session.trace.add(sessionScope, 'resumed');
    await session._save();
    return session;
  }

  /// Forgets the in-memory session without deleting what was stored. Used by
  /// tests and by starting a fresh assessment; the record on disk is evidence
  /// and is not thrown away as a side effect of leaving a screen.
  static void clearCurrent() => _current = null;

  /// Records one subtest's result and saves.
  ///
  /// The save point that matters most: called after every subtest, so the most
  /// a crash can cost is the subtest in progress rather than the whole session.
  Future<void> recordOutcome(SubtestOutcome outcome) async {
    globals.voiceOutcomes[outcome.subtestId] = outcome;
    trace.add(
      outcome.subtestId,
      outcome.skipped ? TraceEventType.skipped : TraceEventType.scored,
      data: {
        'score': outcome.score,
        'maxScore': outcome.maxScore,
        'skipped': outcome.skipped,
      },
    );
    await syncFromGlobals();
  }

  /// Records the five original subtests' scores and saves. They are written
  /// straight to globals by their own pages, so this only has to pull them in.
  Future<void> recordScores() => syncFromGlobals();

  /// Copies the module globals into the durable record and writes it.
  Future<void> syncFromGlobals() async {
    _record = _record.copyWith(
      larkScore: globals.larkScore,
      clockScore: globals.clockScore,
      animalScore: globals.animalScore,
      attentionScore: globals.attentionScore,
      reorderScore: globals.reorderScore,
      correctOrder: List.of(globals.correctOrder),
      voiceOutcomes: Map.of(globals.voiceOutcomes),
    );
    await _save();
  }

  /// Marks the session finished. A completed record is never offered for
  /// resume — reopening the app after finishing should not drop the clinician
  /// back into an assessment that is already done.
  Future<void> complete() async {
    trace.add(sessionScope, 'completed');
    await syncFromGlobals();
    _record = _record.copyWith(completed: true);
    await _save();
  }

  /// Pushes a resumed record back into the globals the pages read.
  void _writeGlobals() {
    globals.larkScore = _record.larkScore;
    globals.clockScore = _record.clockScore;
    globals.animalScore = _record.animalScore;
    globals.attentionScore = _record.attentionScore;
    globals.reorderScore = _record.reorderScore;
    globals.correctOrder
      ..clear()
      ..addAll(_record.correctOrder);
    globals.voiceOutcomes
      ..clear()
      ..addAll(_record.voiceOutcomes);
  }

  Future<void> _save() async {
    // Deliberately not rethrowing. A failed write must not take down a session
    // in progress — everything is still in memory and the assessment can
    // finish. Losing persistence is a degradation; losing the patient's
    // session in front of them is the thing this class exists to prevent.
    try {
      await _store.save(_record);
    } catch (_) {}
  }
}

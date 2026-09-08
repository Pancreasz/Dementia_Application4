/// Per-domain analysis of one session: a status, the points behind it, and
/// descriptive observations underneath.
///
/// WHERE THE THREE CLASSES COME FROM
/// ---------------------------------
/// From the MoCA points, and from nothing else. Full marks / partial / zero,
/// per domain. The point outcome is a validated instrument; none of the
/// measurements below are. Binning an unnormed latency into
/// "normal / mild / severe" would put a label on a patient's brain function
/// with no scale, no norms and no validation behind it — the same thing
/// `SessionTotal.category` already refuses to do for a partial administration,
/// where it returns no category at all rather than an invented one.
///
/// Measurements appear only as descriptive detail. They may qualify a pass in
/// the safe direction ("passed, but only just above the threshold"); they never
/// move anyone into a worse class on their own. Nothing in this file reads a
/// measurement to decide a [DomainStatus] — [DomainAnalysis.status] is a
/// function of `score` and `maxScore` and cannot see the observations.
///
/// Wording carries as much of this as the logic does. "3 misses, all in the
/// last third" is defensible with no dataset behind it. "Attention: 62nd
/// percentile" is not, and the only difference is phrasing.
///
/// WHAT IS DELIBERATELY ABSENT
/// ---------------------------
/// Some measurements the improvement plan names are not captured by the app at
/// all — per-subtraction timing on Serial 7s is the largest one left. Those
/// domains say so, through [ObservationTone.notCaptured], rather than showing a
/// short section and letting it read as "nothing to report". Absence of
/// measurement and absence of finding are different claims and this page must
/// not merge them.
///
/// The same tone covers a session recorded before a capture existed: naming
/// keystrokes and trail-making strokes are both collected now, but a record
/// saved last month has neither, and it says so rather than reporting zero.
library;

import '../moca/app_language.dart';
import '../moca/event_trace.dart';
import '../moca/session_record.dart';
import '../scoring/sentence_repetition.dart';
import '../scoring/subtest_outcome.dart';

/// The three classes, plus the refusal.
enum DomainStatus {
  /// Every administered point in the domain was earned.
  full,

  /// Some but not all.
  partial,

  /// None of them.
  none,

  /// Nothing in this domain was administered, so there is no class to give.
  /// Distinct from [none], which is a real finding about a real attempt.
  notAdministered,
}

/// What kind of statement an observation is. Never a severity.
enum ObservationTone {
  /// Descriptive. What happened, in the patient's own numbers.
  neutral,

  /// Something about the *measurement* is suspect — a threshold artefact, an
  /// ASR artefact, a known app defect. A statement about the app, not about
  /// the patient, and it is shown as such.
  caution,

  /// Nothing was recorded, so nothing can be said.
  notCaptured,
}

class Observation {
  final String text;
  final ObservationTone tone;

  const Observation(this.text, {this.tone = ObservationTone.neutral});

  @override
  String toString() => '$tone: $text';
}

/// One MoCA domain's result and the descriptive detail behind it.
class DomainAnalysis {
  /// Stable key for this analysis domain. Not the same set as the activity
  /// domains — MoCA separates Naming from Language and this page follows the
  /// instrument — which is why [activityDomainId] exists separately.
  final String id;

  /// Already localized: this whole type is built at page-build time, when the
  /// administration language is fixed.
  final String name;

  /// Which entry in `kActivityDomains` engages this domain. Two analysis
  /// domains (Naming, Language) point at the same activity domain.
  final String activityDomainId;

  /// Points earned, and the sum of the maxScores of the subtests that were
  /// actually administered. A skipped subtest is excluded from both sides,
  /// exactly as `computeSessionTotal` treats it — counting a subtest the
  /// backend was down for as a zero would manufacture a deficit.
  final int score;
  final int maxScore;

  /// Localized names of the subtests that fed this domain, and of those that
  /// were skipped. The skipped list is shown: a domain scored on two of its
  /// four subtests is a weaker statement than one scored on all four.
  final List<String> administered;
  final List<String> skipped;

  final List<Observation> observations;

  const DomainAnalysis({
    required this.id,
    required this.name,
    required this.activityDomainId,
    required this.score,
    required this.maxScore,
    required this.administered,
    required this.skipped,
    required this.observations,
  });

  /// From the points alone. See the library comment.
  DomainStatus get status {
    if (maxScore == 0) return DomainStatus.notAdministered;
    if (score >= maxScore) return DomainStatus.full;
    if (score == 0) return DomainStatus.none;
    return DomainStatus.partial;
  }
}

/// What the page has to say before it shows a single domain.
///
/// Returned from here rather than written inline in the widget, for the same
/// reason `requiredFraming` is: a layout change must not be able to drop it
/// quietly, and a test can pin it. The first two lines are what keep everything
/// below them honest — without them a reader has no way to tell which parts of
/// the page are a validated instrument and which are description.
List<String> get analysisFraming => AppLanguage.isEnglish
    ? const [
        'The level shown for each area comes from the MoCA points scored in it, '
            'and from nothing else.',
        'The detail underneath describes what happened during the test. It is '
            'not measured against any norm, it is not a percentile, and it does '
            'not change the level.',
        'Some measurements are not recorded at all. Where that is so, it says '
            'so — that is not the same as nothing being wrong.',
        'This app is a screening tool, not a diagnosis. Discuss these results '
            'with a doctor.',
      ]
    : const [
        'ระดับผลของแต่ละด้าน มาจากคะแนน MoCA ของด้านนั้นเท่านั้น ไม่ได้มาจากค่าที่วัดอื่นใด',
        'รายละเอียดด้านล่างเป็นการบรรยายสิ่งที่เกิดขึ้นระหว่างทำแบบทดสอบ '
            'ไม่ได้เทียบกับค่าปกติใด ไม่ใช่เปอร์เซ็นไทล์ และไม่ได้ทำให้ระดับผลเปลี่ยน',
        'ค่าที่วัดบางอย่างยังไม่ได้ถูกบันทึกไว้เลย ในกรณีนั้นจะระบุไว้ตรง ๆ '
            'ซึ่งไม่ได้แปลว่าไม่มีความผิดปกติ',
        'แอปนี้เป็นเครื่องมือคัดกรองเบื้องต้น ไม่ใช่การวินิจฉัยโรค ควรนำผลไปปรึกษาแพทย์',
      ];

/// Every domain, in the order the MoCA form lists them.
List<DomainAnalysis> analyseSession(SessionRecord record) => [
      _visuospatial(record),
      _naming(record),
      _attention(record),
      _language(record),
      _abstraction(record),
      _delayedRecall(record),
      _orientation(record),
    ];

// ---------------------------------------------------------------------------
// Domains
// ---------------------------------------------------------------------------

DomainAnalysis _visuospatial(SessionRecord r) {
  final obs = <Observation>[..._trailObservations(r)];

  // The clock classifier is cumulative 0-3 (1 = contour, 2 = + numbers,
  // 3 = + hands), so the score already names the failure point with no model
  // change and no new measurement.
  obs.add(switch (r.clockScore) {
    0 => Observation(t('นาฬิกา: ยังวาดกรอบหน้าปัดไม่สำเร็จ',
        'Clock: the outline was not completed.')),
    1 => Observation(t('นาฬิกา: มีกรอบหน้าปัด แต่ตัวเลขยังไม่ครบหรือไม่เข้าที่',
        'Clock: the outline is there; the numbers were not placed.')),
    2 => Observation(t(
        'นาฬิกา: มีกรอบหน้าปัดและตัวเลข แต่เข็มยังไม่ถูกต้อง — เข็มเป็นส่วนที่ใช้การวางแผนมากที่สุด และมักเป็นส่วนที่หายไปก่อน',
        'Clock: outline and numbers are there; the hands were not set. The hands are the most executive-loaded element, and the one most commonly lost first.')),
    _ => Observation(t('นาฬิกา: ครบทั้งกรอบหน้าปัด ตัวเลข และเข็ม',
        'Clock: outline, numbers and hands all present.')),
  });

  if (r.clockScore == 1 || r.clockScore == 2) {
    obs.add(Observation(
      t(
          'การให้คะแนนนาฬิกาเป็นแบบสะสม (กรอบ → ตัวเลข → เข็ม) จึงบอกได้เพียงว่าหยุดที่ขั้นใด กรณีเข็มถูกแต่ตัวเลขผิดจะไม่มีคำอธิบายที่ตรง',
          'The clock score is cumulative (outline → numbers → hands), so it can only say where the drawing stopped. A clock with good hands but disordered numbers has no clean label here.'),
      tone: ObservationTone.caution,
    ));
  }

  return DomainAnalysis(
    id: 'visuospatial-executive',
    name: t('การมองเห็นเชิงมิติ และการบริหารจัดการ', 'Visuospatial / Executive'),
    activityDomainId: 'visuospatial-executive',
    score: r.larkScore + r.clockScore,
    maxScore: 1 + 3,
    administered: [
      t('ลากเส้นสลับตัวเลข-ตัวอักษร', 'Trail making'),
      t('วาดนาฬิกา', 'Clock drawing'),
    ],
    skipped: const [],
    observations: obs,
  );
}

/// One finger-down to finger-up, unpacked from a `stroke` event.
class _Stroke {
  final int startMs;
  final int endMs;
  final int samples;

  const _Stroke(this.startMs, this.endMs, this.samples);

  int get drawingMs => endMs - startMs;

  /// Null for an event with no usable points — an old or hand-edited trace,
  /// rather than something the patient did.
  static _Stroke? from(TraceEvent e) {
    final raw = e.data['points'];
    if (raw is! List || raw.isEmpty) return null;
    final times = <int>[
      for (final p in raw)
        if (p is List && p.length >= 3 && p[2] is num) (p[2] as num).toInt(),
    ];
    if (times.isEmpty) return null;
    return _Stroke(times.first, times.last, times.length);
  }
}

/// Trail making, from the raw stroke traces.
///
/// WHAT IS MEASURED AND WHAT IS NOT
/// --------------------------------
/// The ten points are placed at random on every attempt, on a canvas whose
/// size is the device's. So the distance from one point to the next — and with
/// it the time the line between them *should* take — is different in every
/// session and on every phone. Anything proportional to distance (speed, time
/// per line) is therefore not comparable between sessions, and none is
/// reported as though it were.
///
/// What survives that is the split between moving and not moving. The pause
/// between lifting the finger and putting it down again is search-and-plan
/// time — find the next label, decide it is next — and it barely depends on
/// how far apart the two points happen to be. That is the measure this reads,
/// and, exactly as with typing in [_namingObservations], a pause is only ever
/// compared against this patient's own other pauses.
List<Observation> _trailObservations(SessionRecord r) {
  final events = r.trace.forSubtest('trail-making');
  if (events.isEmpty) {
    return [
      Observation(
        t(
            'การลากเส้น: ไม่มีข้อมูลเวลาสำหรับรอบนี้ — อาจเป็นเซสชันที่บันทึกไว้ก่อนมีการเก็บจังหวะการลากเส้น จึงบอกได้เพียงว่าผ่านหรือไม่ผ่าน',
            'Trail making: no timing was recorded for this session — it may predate the stroke capture — so only pass/fail is known.'),
        tone: ObservationTone.notCaptured,
      ),
    ];
  }

  final obs = <Observation>[];

  // Only the last attempt is described. An abandoned attempt is still in the
  // trace and can be re-analysed later; mixing it into these numbers would
  // report a total time that no single run of the task ever took.
  var attempt = 0;
  for (final e in events) {
    final a = (e.data['attempt'] as num?)?.toInt() ?? 0;
    if (a > attempt) attempt = a;
  }
  final mine = events
      .where((e) => ((e.data['attempt'] as num?)?.toInt() ?? 0) == attempt)
      .toList();

  if (attempt > 0) {
    obs.add(Observation(t(
        'การลากเส้น: เริ่มใหม่ $attempt ครั้ง ตัวเลขด้านล่างเป็นของรอบสุดท้าย — คำแนะนำในแบบทดสอบให้กดเริ่มใหม่เมื่อจุดหลุดออกนอกจอด้วย การเริ่มใหม่จึงไม่ได้แปลว่าทำไม่ได้เสมอไป',
        'Trail making: restarted $attempt time${attempt == 1 ? '' : 's'}; the figures below are the final attempt. The instructions also ask for a restart when a point falls off the screen, so a restart is not by itself a sign of difficulty.')));
  }

  final strokes = <_Stroke>[
    for (final e in mine)
      if (e.type == TraceEventType.stroke)
        if (_Stroke.from(e) case final s?) s,
  ];

  if (strokes.isEmpty) {
    obs.add(Observation(
      t('การลากเส้น: ไม่มีเส้นที่บันทึกไว้ในรอบสุดท้าย',
          'Trail making: no strokes were recorded on the final attempt.'),
      tone: ObservationTone.notCaptured,
    ));
    return obs;
  }

  // The clock starts when the instruction dialog is dismissed, not when the
  // page opens: time spent reading the instructions is not time on task.
  final started = mine.where((e) => e.type == TraceEventType.started);
  final startMs = started.isEmpty ? strokes.first.startMs : started.first.atMs;
  final endMs = strokes.last.endMs;
  final totalMs = endMs - startMs;

  var drawingMs = 0;
  for (final s in strokes) {
    drawingMs += s.drawingMs;
  }
  // Everything that is not finger-on-glass: the first pause after the start,
  // and each lift between two lines.
  final pausedMs = totalMs - drawingMs;

  obs.add(Observation(t(
      'การลากเส้น: ใช้เวลาทั้งหมด ${_seconds(totalMs)} วินาที ลากเส้นจริง ${_seconds(drawingMs)} วินาที และหยุดระหว่างเส้นรวม ${_seconds(pausedMs)} วินาที',
      'Trail making: ${_seconds(totalMs)} s in total — ${_seconds(drawingMs)} s with the finger down and ${_seconds(pausedMs)} s paused between lines.')));

  // Each gap between lifting the finger and putting it down again, plus the
  // one before the very first line.
  final gaps = <int>[strokes.first.startMs - startMs];
  for (var i = 1; i < strokes.length; i++) {
    gaps.add(strokes[i].startMs - strokes[i - 1].endMs);
  }
  final medianGap = _median(gaps);

  var worstAt = 0;
  for (var i = 1; i < gaps.length; i++) {
    if (gaps[i] > gaps[worstAt]) worstAt = i;
  }
  final worst = gaps[worstAt];
  if (medianGap != null && medianGap > 0 && worst > medianGap * 3 && worst > 2000) {
    obs.add(Observation(worstAt == 0
        ? t(
            'การลากเส้น: หยุดคิดก่อนเริ่มเส้นแรก ${_seconds(worst)} วินาที เทียบกับจังหวะปกติของตนเองที่ ${_seconds(medianGap)} วินาทีระหว่างเส้น',
            'Trail making: ${_seconds(worst)} s before the first line, against this patient\'s own typical ${_seconds(medianGap)} s between lines.')
        : t(
            'การลากเส้น: หยุดนานที่สุด ${_seconds(worst)} วินาที ก่อนเส้นที่ ${worstAt + 1} เทียบกับจังหวะปกติของตนเองที่ ${_seconds(medianGap)} วินาที',
            'Trail making: the longest pause was ${_seconds(worst)} s, before line ${worstAt + 1}, against this patient\'s own typical ${_seconds(medianGap)} s between lines.')));
  }

  // Nine lines join ten points. More strokes than that means lines were drawn
  // that the solution does not need — retraced, started and abandoned, or
  // simply a finger put down in the wrong place.
  const needed = 9;
  if (strokes.length > needed) {
    final extra = strokes.length - needed;
    obs.add(Observation(t(
        'การลากเส้น: ลากทั้งหมด ${strokes.length} เส้น ในขณะที่การเชื่อมจุดสิบจุดต้องใช้ $needed เส้น เกินมา $extra เส้น',
        'Trail making: ${strokes.length} strokes drawn, where joining ten points needs $needed — $extra more than the task requires.')));
  } else if (strokes.length < needed) {
    obs.add(Observation(t(
        'การลากเส้น: ลากเพียง ${strokes.length} เส้น จาก $needed เส้นที่ต้องใช้เชื่อมจุดทั้งสิบ',
        'Trail making: only ${strokes.length} of the $needed strokes needed to join all ten points were drawn.')));
  }

  // Why the point was lost, from the check that scored it.
  final scored = mine.where((e) => e.type == TraceEventType.scored).toList();
  if (scored.isNotEmpty && (scored.last.data['score'] as num?)?.toInt() == 0) {
    obs.add(Observation(scored.last.data['linesCross'] == true
        ? t('การลากเส้น: ไม่ได้คะแนนเพราะมีเส้นตัดกัน',
            'Trail making: the point was lost because two lines crossed.')
        : t('การลากเส้น: ไม่ได้คะแนนเพราะลำดับการเชื่อมจุดไม่ถูกต้อง',
            'Trail making: the point was lost because the points were not joined in the right order.')));
  }

  obs.add(Observation(
    t(
        'ตำแหน่งจุดทั้งสิบสุ่มใหม่ทุกครั้งและขึ้นกับขนาดหน้าจอ ระยะระหว่างจุดจึงไม่เท่ากันในแต่ละครั้ง เวลารวมข้างต้นใช้เทียบข้ามครั้งหรือข้ามเครื่องไม่ได้',
        'The ten points are placed at random each attempt, on a canvas the size of the device screen, so the distances differ every time. The total time above cannot be compared between sessions or between devices.'),
    tone: ObservationTone.caution,
  ));

  return obs;
}

String _seconds(int ms) => (ms / 1000).toStringAsFixed(1);

DomainAnalysis _naming(SessionRecord r) => DomainAnalysis(
      id: 'naming',
      name: t('การเรียกชื่อ', 'Naming'),
      activityDomainId: 'naming-language',
      score: r.animalScore,
      maxScore: 3,
      administered: [t('ทายชื่อสัตว์ 3 ชนิด', 'Naming three animals')],
      skipped: const [],
      observations: _namingObservations(r),
    );

/// Naming, from the in-app keyboard's raw key events.
///
/// The one confound that governs everything here: typing speed varies
/// enormously with age and device familiarity, and this population is elderly.
/// Time-to-first-key is fairly robust — it is retrieval, and a slow typist has
/// not started typing yet either way. Inter-key intervals are NOT: a slow
/// typist and a hesitant one look identical in absolute terms. So intervals are
/// only ever reported against the patient's OWN median across all three
/// animals, never against any external figure.
List<Observation> _namingObservations(SessionRecord r) {
  final events = r.trace.forSubtest('naming');
  if (events.isEmpty) {
    return [
      Observation(
        t(
            'ไม่มีข้อมูลการพิมพ์สำหรับรอบนี้ — อาจเป็นเซสชันที่บันทึกไว้ก่อนมีแป้นพิมพ์ในแอป',
            'No typing data for this session — it may have been recorded before the in-app keyboard existed.'),
        tone: ObservationTone.notCaptured,
      ),
    ];
  }

  final obs = <Observation>[];

  // Which keyboard was used. A keypress on Kedmanee and one on the
  // alphabetical grid are not the same event — the character sits somewhere
  // else and is found a different way — so a session that switched layouts has
  // no single baseline, and the intervals below are withheld rather than
  // averaged across the two.
  final layouts = <String>{
    for (final e in events)
      if (e.data['layout'] is String) e.data['layout'] as String,
  };
  final mixedLayouts = layouts.length > 1;

  // Every inter-key gap in the whole subtest, so a per-item gap can be read
  // against this patient's own typical pace rather than an invented one.
  final allGaps = <int>[];
  for (var i = 1; i < events.length; i++) {
    if (events[i].type != TraceEventType.keyPressed) continue;
    if (events[i - 1].type != TraceEventType.keyPressed) continue;
    allGaps.add(events[i].atMs - events[i - 1].atMs);
  }
  final median = mixedLayouts ? null : _median(allGaps);

  if (layouts.length == 1) {
    obs.add(Observation(layouts.first == 'standard'
        ? t('ใช้แป้นพิมพ์แบบปกติ (เกษมณี/QWERTY) ซึ่งมีปุ่ม Shift',
            'Typed on the standard layout (Kedmanee/QWERTY), which has a shift key.')
        : t('ใช้แป้นพิมพ์แบบเรียงตามตัวอักษร ซึ่งแสดงทุกตัวอักษรพร้อมกัน',
            'Typed on the alphabetical layout, which shows every character at once.')));
  } else if (mixedLayouts) {
    obs.add(Observation(
      t(
          'เปลี่ยนแป้นพิมพ์ระหว่างทำข้อนี้ จังหวะการพิมพ์ก่อนและหลังเปลี่ยนจึงเทียบกันไม่ได้ และไม่ได้นำมาคิดเป็นฐานของผู้เข้ารับการทดสอบ',
          'The keyboard layout was changed during this subtest. Typing rhythm either side of the change is not the same measurement, so no typing baseline is reported for this session.'),
      tone: ObservationTone.caution,
    ));
  }

  final items = <int>{
    for (final e in events)
      if (e.data['itemIndex'] is num) (e.data['itemIndex'] as num).toInt(),
  }.toList()
    ..sort();

  for (final index in items) {
    final forItem = events
        .where((e) => (e.data['itemIndex'] as num?)?.toInt() == index)
        .toList();
    final shown = forItem.where((e) => e.type == TraceEventType.itemShown);
    final keys =
        forItem.where((e) => e.type == TraceEventType.keyPressed).toList();
    final deletes =
        forItem.where((e) => e.type == TraceEventType.keyDeleted).length;
    final submit =
        forItem.where((e) => e.type == TraceEventType.submitted).toList();
    if (submit.isEmpty) continue;

    final answer = (submit.last.data['answer'] as String?) ?? '';
    final target = (submit.last.data['target'] as String?) ?? '';
    final correct = submit.last.data['correct'] == true;
    final label = target.isEmpty ? '#${index + 1}' : target;

    if (answer.isEmpty) {
      obs.add(Observation(t('$label: ไม่ได้ตอบ', '$label: no answer given.')));
      continue;
    }

    // Time to first keypress: the closest available proxy for word-finding.
    final int? toFirstKey = (shown.isEmpty || keys.isEmpty)
        ? null
        : keys.first.atMs - shown.first.atMs;

    obs.add(Observation(correct
        ? t('$label: ตอบถูก', '$label: correct.')
        : t('$label: ตอบว่า "$answer"', '$label: answered "$answer".')));

    if (toFirstKey != null) {
      obs.add(Observation(t(
          '$label: เริ่มพิมพ์หลังเห็นภาพ ${(toFirstKey / 1000).toStringAsFixed(1)} วินาที',
          '$label: started typing ${(toFirstKey / 1000).toStringAsFixed(1)} s after the picture appeared.')));
    }

    // The shape the plan names: a long search followed by fluent typing is
    // retrieval difficulty, not motor difficulty.
    final itemGaps = <int>[
      for (var i = 1; i < keys.length; i++) keys[i].atMs - keys[i - 1].atMs,
    ];
    if (toFirstKey != null && median != null && itemGaps.isNotEmpty) {
      final itemMedian = _median(itemGaps)!;
      if (toFirstKey > 5000 && itemMedian <= median) {
        obs.add(Observation(t(
            '$label: ใช้เวลานานกว่าจะเริ่มพิมพ์ แล้วพิมพ์ต่อเนื่องตามปกติ — เป็นเรื่องการนึกคำ ไม่ใช่การพิมพ์',
            '$label: a long pause before the first key, then typing at this patient\'s usual pace — the word was hard to retrieve, not hard to type.')));
      }
      // A mid-word stall, measured against this patient's own baseline.
      final worst = itemGaps.reduce((a, b) => a > b ? a : b);
      if (median > 0 && worst > median * 3 && worst > 2000) {
        obs.add(Observation(t(
            '$label: มีการหยุดกลางคำ ${(worst / 1000).toStringAsFixed(1)} วินาที เทียบกับจังหวะปกติของตนเองที่ ${(median / 1000).toStringAsFixed(1)} วินาที',
            '$label: paused ${(worst / 1000).toStringAsFixed(1)} s mid-word, against this patient\'s own typical ${(median / 1000).toStringAsFixed(1)} s between keys.')));
      }
    }

    if (deletes > 0) {
      obs.add(Observation(t(
          '$label: แก้ไข $deletes ครั้งระหว่างพิมพ์',
          '$label: $deletes correction${deletes == 1 ? '' : 's'} while typing.')));
    }

    // A near-miss spelling is a typing error, not anomia. Flagged as a caution
    // because it is a statement about the scoring, not about the patient — and
    // deliberately NOT acted on: whether "camle" should still cost the point is
    // a clinical decision, not one this page gets to make quietly.
    if (!correct && target.isNotEmpty) {
      final closeness = similarityRatio(answer.toLowerCase(), target.toLowerCase());
      if (closeness >= 0.6) {
        obs.add(Observation(
          t(
              '$label: "$answer" ต่างจาก "$target" เพียงเล็กน้อย (ความใกล้เคียง ${closeness.toStringAsFixed(2)}) — น่าจะเป็นการพิมพ์ผิดมากกว่าการนึกชื่อไม่ออก แต่ยังถูกนับเป็นตอบผิด',
              '$label: "$answer" is one or two characters from "$target" (closeness ${closeness.toStringAsFixed(2)}) — that looks like a typing error rather than a naming failure, but it is still scored as wrong.'),
          tone: ObservationTone.caution,
        ));
      }
    }
  }

  if (median != null) {
    obs.add(Observation(t(
        'จังหวะการพิมพ์ปกติของผู้เข้ารับการทดสอบรายนี้คือ ${(median / 1000).toStringAsFixed(1)} วินาทีต่อตัวอักษร ใช้เป็นฐานเปรียบเทียบกับตนเองเท่านั้น ไม่ได้เทียบกับผู้อื่น',
        'This patient\'s own typing pace was ${(median / 1000).toStringAsFixed(1)} s per character. It is used only to compare them against themselves — typing speed varies far too much with age and device familiarity to compare between people.')));
  }

  return obs;
}

DomainAnalysis _attention(SessionRecord r) {
  final obs = <Observation>[];
  final administered = <String>[t('ลบเลขทีละ 7', 'Serial 7s')];
  final skipped = <String>[];

  // Serial 7s always runs; the three voice/tap items may not.
  var score = r.attentionScore;
  var maxScore = 3;

  obs.add(Observation(
    t(
        'ลบเลขทีละ 7: บันทึกเฉพาะคำตอบ ไม่ได้บันทึกเวลาต่อข้อ จึงยังบอกไม่ได้ว่าลบผิดจากเลขที่ตนเองตอบไว้ก่อนหน้า (ความจำใช้งานยังดี) หรือหลุดจากยอดสะสมไปเลย',
        'Serial 7s: only the answers are recorded, not the time per subtraction, so a patient who subtracted correctly from their own wrong answer — working memory intact, arithmetic slipped — cannot yet be told apart from one who lost the running total.'),
    tone: ObservationTone.notCaptured,
  ));

  final forward = _administeredOutcome(r, 'digit-span-forward');
  final backward = _administeredOutcome(r, 'digit-span-backward');
  final vigilance = _administeredOutcome(r, 'vigilance');

  for (final entry in [
    (forward, 'digit-span-forward', t('ทวนตัวเลขตามลำดับ', 'Digit span forward')),
    (backward, 'digit-span-backward', t('ทวนตัวเลขย้อนกลับ', 'Digit span backward')),
    (vigilance, 'vigilance', t('ความตื่นตัว (แตะเมื่อได้ยินเลข 1)', 'Vigilance')),
  ]) {
    if (entry.$1 == null) {
      skipped.add(entry.$3);
    } else {
      administered.add(entry.$3);
      score += entry.$1!.score;
      maxScore += entry.$1!.maxScore;
    }
  }

  if (forward != null) obs.addAll(_digitSpanObservations(forward, forwardSpan: true));
  if (backward != null) obs.addAll(_digitSpanObservations(backward, forwardSpan: false));

  // The cross-subtest reading, which neither outcome carries on its own.
  if (forward != null && backward != null) {
    if (forward.score == forward.maxScore && backward.score < backward.maxScore) {
      obs.add(Observation(t(
          'ทวนตามลำดับได้ แต่ทวนย้อนกลับไม่ได้ — ชี้ไปที่ภาระด้านการจัดการข้อมูลในใจ มากกว่าช่วงความจำ',
          'Forward intact, backward failed — this points at executive load rather than at memory span.')));
    } else if (forward.score == 0 && backward.score == 0) {
      obs.add(Observation(t(
          'ทวนไม่ได้ทั้งสองแบบ — เป็นเรื่องช่วงความสนใจพื้นฐาน ก่อนจะตีความถึงการจัดการข้อมูลในใจ',
          'Both failed — that is basic attention span, before any executive interpretation.')));
    }
  }

  if (vigilance != null) obs.addAll(_vigilanceObservations(vigilance));

  obs.addAll(_traceObservations(r, const [
    'digit-span-forward',
    'digit-span-backward',
    'vigilance',
  ]));

  return DomainAnalysis(
    id: 'attention',
    name: t('สมาธิ', 'Attention'),
    activityDomainId: 'attention',
    score: score,
    maxScore: maxScore,
    administered: administered,
    skipped: skipped,
    observations: obs,
  );
}

DomainAnalysis _language(SessionRecord r) {
  final obs = <Observation>[];
  final administered = <String>[];
  final skipped = <String>[];
  var score = 0;
  var maxScore = 0;

  for (final entry in [
    ('sentence-repetition-1', t('พูดทวนประโยคที่ 1', 'Sentence repetition 1')),
    ('sentence-repetition-2', t('พูดทวนประโยคที่ 2', 'Sentence repetition 2')),
    ('verbal-fluency', t('บอกคำตามตัวอักษร', 'Verbal fluency')),
  ]) {
    final outcome = _administeredOutcome(r, entry.$1);
    if (outcome == null) {
      skipped.add(entry.$2);
      continue;
    }
    administered.add(entry.$2);
    score += outcome.score;
    maxScore += outcome.maxScore;
    if (entry.$1 == 'verbal-fluency') {
      obs.addAll(_fluencyObservations(outcome));
    } else {
      obs.addAll(_repetitionObservations(outcome, entry.$2));
    }
  }

  obs.addAll(_traceObservations(r, const [
    'sentence-repetition-1',
    'sentence-repetition-2',
    'verbal-fluency',
  ]));

  return DomainAnalysis(
    id: 'language',
    name: t('ภาษา', 'Language'),
    activityDomainId: 'naming-language',
    score: score,
    maxScore: maxScore,
    administered: administered,
    skipped: skipped,
    observations: obs,
  );
}

DomainAnalysis _abstraction(SessionRecord r) {
  final obs = <Observation>[];
  final administered = <String>[];
  final skipped = <String>[];
  var score = 0;
  var maxScore = 0;

  for (final entry in [
    ('abstraction-1', t('รถไฟกับจักรยาน', 'Train and bicycle')),
    ('abstraction-2', t('นาฬิกากับไม้บรรทัด', 'Watch and ruler')),
  ]) {
    final outcome = _administeredOutcome(r, entry.$1);
    if (outcome == null) {
      skipped.add(entry.$2);
      continue;
    }
    administered.add(entry.$2);
    score += outcome.score;
    maxScore += outcome.maxScore;
    obs.addAll(_abstractionObservations(outcome, entry.$2));
  }

  obs.addAll(_traceObservations(r, const ['abstraction-1', 'abstraction-2']));

  return DomainAnalysis(
    id: 'abstraction',
    name: t('ความคิดรวบยอด', 'Abstraction'),
    activityDomainId: 'abstraction-reasoning',
    score: score,
    maxScore: maxScore,
    administered: administered,
    skipped: skipped,
    observations: obs,
  );
}

DomainAnalysis _delayedRecall(SessionRecord r) {
  final obs = <Observation>[];

  final event = _lastEvent(r.trace, 'delayed-recall', TraceEventType.scored);
  final recalled = _strings(event?.data, 'recalled');
  final target = _strings(event?.data, 'target');

  if (event == null || recalled.isEmpty || target.isEmpty) {
    obs.add(Observation(
      t(
          'บันทึกไว้เฉพาะจำนวนที่ถูกตำแหน่ง ไม่ได้บันทึกลำดับที่จัดจริง จึงยังแยกไม่ได้ว่าจำภาพได้แต่เรียงผิด หรือจำภาพไม่ได้',
          'Only the number of correct positions was recorded, not the arrangement itself, so recognising all five pictures but ordering them wrongly cannot be told apart from not recognising them.'),
      tone: ObservationTone.notCaptured,
    ));
  } else {
    final recognised = recalled.where(target.contains).toSet().length;
    obs.add(Observation(t(
        'จำภาพได้ถูกต้อง $recognised จาก ${target.length} ภาพ (ไม่นับตำแหน่ง) และวางถูกตำแหน่ง ${r.reorderScore} ภาพ',
        'Recognised $recognised of ${target.length} pictures regardless of position, and placed ${r.reorderScore} of them in the right position.')));

    if (recognised < target.length) {
      obs.add(Observation(t(
          'มีภาพที่จำไม่ได้ — เป็นเรื่องการจดจำหรือการเก็บข้อมูล ไม่ใช่เรื่องการเรียงลำดับ',
          'Not every picture was recognised — that is encoding or storage, not sequencing.')));
    } else if (r.reorderScore < target.length) {
      // Every picture came back; only the order is wrong. Displacement of one
      // place throughout is a different finding from scattered placement.
      final displacements = <int>[
        for (var i = 0; i < recalled.length; i++)
          if (target.contains(recalled[i])) (target.indexOf(recalled[i]) - i).abs(),
      ];
      final adjacentOnly = displacements.every((d) => d <= 1);
      obs.add(Observation(
        adjacentOnly
            ? t('จำภาพได้ครบ แต่สลับตำแหน่งกับภาพที่อยู่ติดกันเท่านั้น — ยังมีร่องรอยของลำดับอยู่บางส่วน',
                'All pictures recognised, and every one that moved moved only one place — adjacent swaps, so part of the order was retained.')
            : t('จำภาพได้ครบ แต่ลำดับคลาดเคลื่อนมากกว่าการสลับที่ติดกัน',
                'All pictures recognised, but the displacement is wider than adjacent swaps.'),
      ));
      obs.add(Observation(t(
          'จำภาพได้ครบทั้งห้าแต่เรียงผิด ให้คะแนนเท่ากับการเรียงแบบสุ่ม ทั้งที่เป็นคนละเรื่องกันในทางคลินิก',
          'Recognising all five pictures but ordering them wrongly scores the same as random placement, although clinically the two are not the same finding.')));
    }
  }

  return DomainAnalysis(
    id: 'delayed-recall',
    name: t('ความจำ', 'Delayed recall'),
    activityDomainId: 'memory',
    score: r.reorderScore,
    maxScore: 5,
    administered: [t('เรียงลำดับภาพ 5 ภาพ', 'Reordering five pictures')],
    skipped: const [],
    observations: obs,
  );
}

DomainAnalysis _orientation(SessionRecord r) {
  final outcome = _administeredOutcome(r, 'orientation');
  if (outcome == null) {
    return DomainAnalysis(
      id: 'orientation',
      name: t('การรับรู้เวลาและสถานที่', 'Orientation'),
      activityDomainId: 'orientation',
      score: 0,
      maxScore: 0,
      administered: const [],
      skipped: [t('การรับรู้เวลาและสถานที่', 'Orientation')],
      observations: const [],
    );
  }

  const fieldOrder = ['day', 'date', 'month', 'year', 'place', 'province'];
  final labels = {
    'day': t('วัน', 'day'),
    'date': t('วันที่', 'date'),
    'month': t('เดือน', 'month'),
    'year': t('ปี', 'year'),
    'place': t('สถานที่', 'place'),
    'province': t('จังหวัด', 'province'),
  };

  final wrong = [
    for (final field in fieldOrder)
      if (outcome.detail[field] == false) field,
  ];

  final obs = <Observation>[];
  if (wrong.isEmpty) {
    obs.add(Observation(t('ตอบถูกทั้งหกข้อ', 'All six items correct.')));
  } else {
    obs.add(Observation(t(
        'ตอบไม่ถูกในข้อ: ${wrong.map((f) => labels[f]).join(', ')}',
        'Incorrect: ${wrong.map((f) => labels[f]).join(', ')}.')));

    // Which field failed matters more than how many did.
    if (wrong.contains('date') && !wrong.contains('month') && !wrong.contains('year')) {
      obs.add(Observation(t(
          'วันที่คลาดเคลื่อนไปหนึ่งถึงสองวันพบได้บ่อยในคนทั่วไป โดยเฉพาะเมื่ออยู่ในโรงพยาบาล จึงเป็นหลักฐานที่อ่อนเมื่ออยู่ลำพัง',
          'A date off by a day or two is common in healthy people, especially in a hospital setting. On its own it is weak evidence.')));
    }
    if (wrong.contains('month') || wrong.contains('year')) {
      obs.add(Observation(t('เดือนหรือปีที่ผิด มีน้ำหนักมากกว่าวันที่ผิด',
          'A wrong month or year carries substantially more weight than a wrong date.')));
    }
    if (wrong.contains('place') || wrong.contains('province')) {
      obs.add(Observation(
        t(
            'สถานที่และจังหวัดถูกกำหนดไว้ตายตัวในโค้ด (โรงพยาบาลศิริราช / กรุงเทพ) หากใช้งานที่อื่น ข้อนี้จะผิดสำหรับผู้เข้ารับการทดสอบทุกคน — ยังไม่ควรอ่านเป็นผลของผู้ป่วยจนกว่าจะแก้',
            'Place and province are compile-time constants in the app. At any other site these two items are wrong for every patient, so a failure here may be an app defect and must not be read as a patient finding until that is fixed.'),
        tone: ObservationTone.caution,
      ));
    }
  }

  obs.addAll(_traceObservations(r, const ['orientation']));

  return DomainAnalysis(
    id: 'orientation',
    name: t('การรับรู้เวลาและสถานที่', 'Orientation'),
    activityDomainId: 'orientation',
    score: outcome.score,
    maxScore: outcome.maxScore,
    administered: [t('การรับรู้เวลาและสถานที่ 6 ข้อ', 'Six orientation items')],
    skipped: const [],
    observations: obs,
  );
}

// ---------------------------------------------------------------------------
// Per-subtest observations
// ---------------------------------------------------------------------------

List<Observation> _digitSpanObservations(
  SubtestOutcome outcome, {
  required bool forwardSpan,
}) {
  final label = forwardSpan
      ? t('ทวนตามลำดับ', 'Digit span forward')
      : t('ทวนย้อนกลับ', 'Digit span backward');
  final spoken = (outcome.detail['spoken'] as String?) ?? '';
  final expected = (outcome.detail['expected'] as String?) ?? '';

  if (outcome.score == outcome.maxScore) {
    return [Observation(t('$label: ถูกต้อง ($spoken)', '$label: correct ($spoken).'))];
  }

  if (spoken.isEmpty) {
    return [
      Observation(
        t('$label: ไม่มีตัวเลขใดถูกถอดออกมาจากเสียงที่บันทึก — อาจเป็นข้อจำกัดของการถอดเสียง ไม่ใช่คำตอบของผู้เข้ารับการทดสอบ',
            '$label: no digits were extracted from the recording at all, which may be a limit of the speech recogniser rather than the patient\'s answer.'),
        tone: ObservationTone.caution,
      ),
    ];
  }

  final obs = <Observation>[
    Observation(t('$label: ตอบ "$spoken" ควรเป็น "$expected"',
        '$label: answered "$spoken", expected "$expected".')),
  ];

  final sortedSpoken = (spoken.split('')..sort()).join();
  final sortedExpected = (expected.split('')..sort()).join();

  if (sortedSpoken == sortedExpected) {
    obs.add(Observation(forwardSpan
        ? t('ตัวเลขครบทุกตัว แต่ลำดับสลับ',
            'Every digit is present; the order changed.')
        : t('ตัวเลขครบทุกตัว แต่ลำดับสลับ — ช่วงความจำยังอยู่ แต่การจัดลำดับใหม่ในใจบกพร่อง ซึ่งเป็นสัญญาณของความจำใช้งาน',
            'Every digit is present but transposed — span (storage) intact, manipulation impaired. That is the working-memory signal.')));
  } else if (_isSubsequence(spoken, expected)) {
    obs.add(Observation(
        spoken.length < expected.length && expected.startsWith(spoken)
            ? t('ตัวเลขท้ายหายไป — เกินช่วงที่จำได้',
                'The final digits are missing — the span limit was exceeded.')
            : t('มีตัวเลขหายไปบางตัว ตัวที่เหลืออยู่ในลำดับเดิม',
                'Some digits are missing; those given keep their original order.')));
  } else if (spoken.length > expected.length) {
    obs.add(Observation(t('มีตัวเลขเกินเข้ามา',
        'Extra digits appeared that were not in the sequence.')));
  }

  return obs;
}

List<Observation> _vigilanceObservations(SubtestOutcome outcome) {
  final misses = _int(outcome.detail, 'misses');
  final falseTaps = _int(outcome.detail, 'falseTaps');
  final latencies = _ints(outcome.detail, 'tapLatencies');
  final missPositions = _ints(outcome.detail, 'missPositions');
  final falsePositions = _ints(outcome.detail, 'falseTapPositions');
  final length = _int(outcome.detail, 'sequenceLength');

  final obs = <Observation>[
    // Counted separately rather than summed. They are two different deficits
    // and the score adds them together.
    Observation(t('ความตื่นตัว: พลาดไม่แตะ $misses ครั้ง แตะเกิน $falseTaps ครั้ง',
        'Vigilance: $misses missed target${misses == 1 ? '' : 's'}, $falseTaps false tap${falseTaps == 1 ? '' : 's'}.')),
  ];

  if (misses > 0 && falseTaps == 0) {
    obs.add(Observation(t('พลาดอย่างเดียว ไม่มีการแตะเกิน — เป็นการหลุดความสนใจเป็นช่วง',
        'Misses only, no false taps — lapses in sustaining attention.')));
  } else if (falseTaps > 0 && misses == 0) {
    obs.add(Observation(t(
        'แตะเกินอย่างเดียว ไม่มีการพลาด — เป็นการตอบสนองที่ยับยั้งไม่อยู่ ซึ่งต่างจากการไม่มีสมาธิ และคะแนนรวมสองอย่างนี้เข้าด้วยกัน',
        'False taps only, no misses — responding without inhibiting, which is clinically distinct from inattention and is summed into the same error count by the score.')));
  }

  // Vigilance decrement: where the errors fell, not how many.
  final errorPositions = [...missPositions, ...falsePositions];
  if (errorPositions.isNotEmpty && length > 0) {
    final lastThird = length * 2 / 3;
    if (errorPositions.every((p) => p >= lastThird)) {
      obs.add(Observation(t(
          'ความผิดพลาดทั้งหมดอยู่ในช่วงท้ายของลำดับ — ทำได้ในตอนแรก แต่รักษาความสนใจไว้ไม่ตลอด',
          'Every error fell in the last third of the sequence — the task could be done, but not kept up.')));
    }
  }

  if (latencies.length >= 2) {
    final min = latencies.reduce((a, b) => a < b ? a : b);
    final max = latencies.reduce((a, b) => a > b ? a : b);
    final mean = latencies.reduce((a, b) => a + b) ~/ latencies.length;
    obs.add(Observation(t(
        'เวลาตอบสนองเฉลี่ย $mean มิลลิวินาที (ช่วง $min–$max) วัดจากจังหวะที่เลขเป้าหมายดังขึ้น',
        'Response time averaged $mean ms (range $min–$max), measured from each target digit\'s onset.')));
  }

  return obs;
}

List<Observation> _repetitionObservations(SubtestOutcome outcome, String label) {
  final similarity = _double(outcome.detail, 'similarity');
  if (similarity == null) return const [];

  // Read from the outcome rather than restated here, so this text cannot drift
  // away from the number the score was actually measured against. Older stored
  // sessions predate the field and fall back to the current constant.
  final threshold =
      _double(outcome.detail, 'threshold') ?? kSentenceSimilarityThreshold;
  final shown = similarity.toStringAsFixed(2);
  final shownThreshold = threshold.toStringAsFixed(2);
  final obs = <Observation>[
    // Shown rather than reduced to pass/fail: it is already computed, and it is
    // the only way anyone can see how near a miss was.
    Observation(t('$label: ความใกล้เคียงกับประโยคต้นฉบับ $shown (เกณฑ์ $shownThreshold)',
        '$label: similarity to the original sentence $shown (threshold $shownThreshold).')),
  ];

  if (outcome.score == 0 && similarity >= threshold - 0.05) {
    obs.add(Observation(
      t(
          'พลาดเกณฑ์เพียงเล็กน้อย และเกณฑ์ $shownThreshold นี้ยังไม่ได้ผ่านการตรวจสอบกับข้อมูลจริง จึงควรอ่านว่าเป็นผลของเกณฑ์ มากกว่าผลของผู้เข้ารับการทดสอบ',
          'That is just under the line, and the $shownThreshold threshold itself has never been validated against real speech. Read this as an artefact of the threshold rather than a finding about the patient.'),
      tone: ObservationTone.caution,
    ));
  }

  return obs;
}

List<Observation> _fluencyObservations(SubtestOutcome outcome) {
  final count = _int(outcome.detail, 'distinctCount');
  final threshold = _int(outcome.detail, 'threshold');
  final rejected = _strings(outcome.detail, 'rejectedWrongLetter');
  final transcript = outcome.transcript;

  final obs = <Observation>[
    Observation(t('บอกคำได้ $count คำใน 60 วินาที (เกณฑ์ $threshold คำ)',
        'Produced $count distinct words in 60 seconds (threshold $threshold).')),
  ];

  if (rejected.isNotEmpty) {
    obs.add(Observation(t(
        'มี ${rejected.length} คำที่ไม่ได้ขึ้นต้นด้วยตัวอักษรที่กำหนด: ${rejected.join(', ')} — เป็นการหลุดกติกาของงาน',
        '${rejected.length} word(s) did not start with the target letter: ${rejected.join(', ')} — a rule-maintenance slip.')));
  }

  final tokens = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  // The known Thai ASR artefact: no spaces means the whole answer arrives as
  // one token, and the count is of whitespace-separated tokens.
  if (tokens.length <= 1 && transcript.length > 30) {
    obs.add(Observation(
      t(
          'คำตอบที่ถอดเสียงได้ยาว ${transcript.length} ตัวอักษร แต่ไม่มีการเว้นวรรค จึงถูกนับเป็นคำเดียว นี่เป็นข้อจำกัดของการถอดเสียงภาษาไทย ไม่ใช่ผลของผู้เข้ารับการทดสอบ',
          'The transcript is ${transcript.length} characters long but contains no spaces, so it counts as one word. That is a known limit of Thai speech recognition, not a patient result.'),
      tone: ObservationTone.caution,
    ));
  } else if (tokens.length > count + rejected.length) {
    final repeats = tokens.length - count - rejected.length;
    obs.add(Observation(t(
        'มีคำซ้ำ $repeats ครั้งในคำตอบ การพูดคำที่ตอบไปแล้วซ้ำเป็นสัญญาณของการตรวจสอบคำตอบตนเองไม่ได้ และไม่ปรากฏในคะแนน เพราะคะแนนนับเฉพาะคำที่ไม่ซ้ำ',
        '$repeats repeated word(s) in the answer. Repeating words already given is a monitoring signal, and it is invisible in the score, which counts only distinct words.')));
  }

  return obs;
}

List<Observation> _abstractionObservations(SubtestOutcome outcome, String label) {
  final detail = outcome.detail;
  final reason = detail['reason'] as String?;
  final bestTerm = detail['best_term'] as String?;
  final category = _double(detail, 'best_category_similarity');
  final stimulus = _double(detail, 'best_stimulus_similarity');
  final threshold = _double(detail, 'threshold');

  if (reason == 'no-response') {
    return [
      Observation(t('$label: ไม่ได้ตอบ — ต่างจากการตอบผิด',
          '$label: no answer was given, which is distinct from a wrong answer.')),
    ];
  }

  final obs = <Observation>[];
  final answer = outcome.transcript.trim();
  if (answer.isNotEmpty) {
    obs.add(Observation(t('$label: ตอบว่า "$answer"', '$label: answered "$answer".')));
  }

  if (category == null) return obs;

  final shownCategory = category.toStringAsFixed(2);
  if (outcome.score > 0) {
    obs.add(Observation(t(
        'ใกล้เคียงกับคำที่จัดเป็นหมวดหมู่ "${bestTerm ?? ''}" ที่ $shownCategory',
        'Closest accepted category term "${bestTerm ?? ''}" at $shownCategory.')));
    return obs;
  }

  // Failed. Which of the three failure shapes it is.
  if (stimulus != null && stimulus >= category) {
    obs.add(Observation(t(
        'คำตอบใกล้เคียงกับตัวสิ่งของที่ยกมา (${stimulus.toStringAsFixed(2)}) มากกว่าใกล้เคียงกับชื่อหมวดหมู่ ($shownCategory) — เป็นการพูดถึงสิ่งของทั้งสองซ้ำ ไม่ได้จัดหมวดหมู่',
        'The answer sits closer to the stimulus objects themselves (${stimulus.toStringAsFixed(2)}) than to any category name ($shownCategory) — restating the two things rather than naming what they are.')));
  } else if (threshold != null && category >= threshold - 0.05) {
    obs.add(Observation(
      t(
          'ใกล้เกณฑ์มาก ($shownCategory เทียบกับเกณฑ์ ${threshold.toStringAsFixed(2)}) และเกณฑ์นี้ยังไม่ได้ตรวจสอบกับข้อมูลจริง จึงน่าจะเป็นผลของเกณฑ์มากกว่าผลของผู้เข้ารับการทดสอบ',
          'Very close to the line ($shownCategory against a threshold of ${threshold.toStringAsFixed(2)}), and that threshold has never been validated. This is more likely an artefact of the threshold than a patient failure.'),
      tone: ObservationTone.caution,
    ));
  } else {
    obs.add(Observation(t(
        'คำตอบไม่ใกล้กับชื่อหมวดหมู่ใดเลย ($shownCategory) — เป็นการบอกลักษณะร่วมของสิ่งของ มากกว่าการจัดหมวดหมู่ ซึ่งเป็นรูปแบบที่ข้อนี้ออกแบบมาเพื่อจับ',
        'The answer is not near any category name ($shownCategory) — property matching rather than category formation, which is the failure this item is designed to catch.')));
  }

  return obs;
}

// ---------------------------------------------------------------------------
// Trace-derived observations that apply to any voice subtest
// ---------------------------------------------------------------------------

/// Retries and backend failures, from the raw trace.
///
/// Kept separate from the scorers because neither is visible in an outcome: a
/// subtest answered first time and one retried three times can carry the same
/// score, and a zero that came from an outage looks exactly like a zero the
/// patient earned.
List<Observation> _traceObservations(SessionRecord r, List<String> subtestIds) {
  final obs = <Observation>[];
  for (final id in subtestIds) {
    final events = r.trace.forSubtest(id);
    final retries = events.where((e) => e.type == TraceEventType.retried).length;
    final failures = events.where((e) => e.type == TraceEventType.failed).length;
    if (retries > 0) {
      obs.add(Observation(t('$id: ทำซ้ำ $retries ครั้ง',
          '$id: re-administered $retries time${retries == 1 ? '' : 's'}.')));
    }
    if (failures > 0) {
      obs.add(Observation(
        t('$id: มีความล้มเหลวของระบบ $failures ครั้งระหว่างทำข้อนี้ คะแนนของข้อนี้อาจสะท้อนระบบ ไม่ใช่ผู้เข้ารับการทดสอบ',
            '$id: $failures system failure(s) during this subtest. Its score may reflect the system rather than the patient.'),
        tone: ObservationTone.caution,
      ));
    }
  }
  return obs;
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/// The outcome for [id], or null when the subtest was never administered.
/// A skipped subtest and one that was never reached are the same thing here.
SubtestOutcome? _administeredOutcome(SessionRecord r, String id) {
  final outcome = r.voiceOutcomes[id];
  if (outcome == null || outcome.skipped) return null;
  return outcome;
}

TraceEvent? _lastEvent(TraceLog trace, String subtestId, String type) {
  TraceEvent? found;
  for (final event in trace.forSubtest(subtestId)) {
    if (event.type == type) found = event;
  }
  return found;
}

/// Whether every character of [part] appears in [whole] in the same order.
bool _isSubsequence(String part, String whole) {
  var i = 0;
  for (final char in whole.split('')) {
    if (i < part.length && part[i] == char) i += 1;
  }
  return i == part.length;
}

/// Median rather than mean: one 30-second stare while the patient looks for a
/// key would drag a mean far away from their actual pace, and the pace is what
/// every other gap is compared against.
int? _median(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = List.of(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) ~/ 2;
}

int _int(Map<String, dynamic> d, String key) => (d[key] as num?)?.toInt() ?? 0;

double? _double(Map<String, dynamic> d, String key) => (d[key] as num?)?.toDouble();

List<int> _ints(Map<String, dynamic> d, String key) => [
      for (final v in (d[key] as List?) ?? const [])
        if (v is num) v.toInt(),
    ];

List<String> _strings(Map<String, dynamic>? d, String key) => [
      for (final v in (d?[key] as List?) ?? const [])
        if (v is String) v,
    ];

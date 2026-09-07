import 'package:flutter/material.dart';

import '../analysis/domain_analysis.dart';
import '../moca/app_language.dart';
import '../moca/live_session.dart';
import '../moca/session_record.dart';

/// Per-domain breakdown, shown between the last subtest and the score.
///
/// It comes BEFORE the result page on purpose. The single number is the thing
/// everyone remembers, and a patient who sees it first reads everything after
/// it as an explanation of a verdict they have already been given. Shown first,
/// the same detail is just what happened during the test.
///
/// The three levels are computed in `lib/analysis/domain_analysis.dart` from
/// the MoCA points alone; this file only decides how they look. Nothing here
/// turns a measurement into a level — see that library's comment for why that
/// separation is load-bearing rather than tidy.
class AnalysisPage extends StatelessWidget {
  /// Injectable so the page can be tested against a built record instead of
  /// whatever the module globals happen to hold.
  final SessionRecord? record;

  const AnalysisPage({super.key, this.record});

  @override
  Widget build(BuildContext context) {
    final domains = analyseSession(record ?? sessionSnapshot());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('ผลแยกตามด้าน', 'Results by area'),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FramingCard(),
              const SizedBox(height: 16),
              for (final domain in domains) ...[
                _DomainCard(domain: domain),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/endpage'),
                child: Text(t('ดูคะแนนรวม', 'See the total score')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The required framing, above every domain.
///
/// Amber and at the top, matching the activities page — a reader who stops
/// halfway down has still read it.
class _FramingCard extends StatelessWidget {
  const _FramingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('วิธีอ่านหน้านี้', 'How to read this page'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in analysisFraming)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $line', style: const TextStyle(fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final DomainAnalysis domain;

  const _DomainCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    final look = _look(domain.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    domain.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(look: look),
              ],
            ),
            const SizedBox(height: 6),
            // The points, stated plainly right under the level, because the
            // level is nothing but a reading of them.
            Text(
              domain.status == DomainStatus.notAdministered
                  ? t('ไม่ได้ทำข้อใดในด้านนี้', 'None of this area was administered')
                  : t('คะแนน ${domain.score} จาก ${domain.maxScore}',
                      'Scored ${domain.score} out of ${domain.maxScore}'),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
            ),
            if (domain.skipped.isNotEmpty) ...[
              const SizedBox(height: 4),
              // Named rather than silently excluded: a domain scored on two of
              // its four subtests is a weaker statement than one scored on all
              // four, and the level alone cannot show that.
              Text(
                t('ข้ามไป: ${domain.skipped.join(', ')}',
                    'Skipped: ${domain.skipped.join(', ')}'),
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (domain.observations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              for (final observation in domain.observations)
                _ObservationRow(observation: observation),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade800,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/activities',
                  arguments: domain.activityDomainId,
                ),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                // "Engages", never "improves". The evidence for domain-targeted
                // cognitive training does not support a promise of gain.
                label: Text(
                  t('กิจกรรมที่ใช้ความสามารถด้านนี้',
                      'Activities that engage this area'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationRow extends StatelessWidget {
  final Observation observation;

  const _ObservationRow({required this.observation});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (observation.tone) {
      // A caution is about the app, not the patient — a threshold that has
      // never been validated, a known defect, a recogniser artefact. It is
      // marked differently so it cannot be read as a finding.
      ObservationTone.caution => (Icons.report_problem_outlined, Colors.amber.shade800),
      ObservationTone.notCaptured => (Icons.remove_circle_outline, Colors.grey.shade600),
      ObservationTone.neutral => (Icons.circle, Colors.blue.shade300),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              icon,
              size: observation.tone == ObservationTone.neutral ? 8 : 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              observation.text,
              style: TextStyle(
                fontSize: 15,
                color: observation.tone == ObservationTone.notCaptured
                    ? Colors.grey.shade700
                    : Colors.black87,
                fontStyle: observation.tone == ObservationTone.notCaptured
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ({String label, Color color}) look;

  const _StatusChip({required this.look});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: look.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: look.color, width: 1.2),
      ),
      child: Text(
        look.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: look.color,
        ),
      ),
    );
  }
}

/// Label and colour for a status.
///
/// The label carries the meaning and the colour only reinforces it. Both are
/// functions of the MoCA points — `DomainStatus` cannot see a measurement — so
/// a red chip here says "no points were scored in this area", never "impaired".
({String label, Color color}) _look(DomainStatus status) => switch (status) {
      DomainStatus.full => (
          label: t('ได้คะแนนเต็ม', 'Full marks'),
          color: Colors.green.shade700,
        ),
      DomainStatus.partial => (
          label: t('ได้บางส่วน', 'Partial'),
          color: Colors.orange.shade800,
        ),
      DomainStatus.none => (
          label: t('ไม่ได้คะแนน', 'No points'),
          color: Colors.red.shade700,
        ),
      // Grey, and worded as an absence of data rather than an absence of
      // ability. `SessionTotal.category` refuses to band a partial
      // administration for the same reason.
      DomainStatus.notAdministered => (
          label: t('ไม่ได้ทำ', 'Not administered'),
          color: Colors.grey.shade600,
        ),
    };

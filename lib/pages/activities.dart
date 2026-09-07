import 'package:flutter/material.dart';

import '../moca/activities.dart';
import '../moca/app_language.dart';

/// Activities that engage each MoCA domain.
///
/// Deliberately NOT personalised to the patient's scores. Highlighting "your
/// weak domains" turns a screening result into a prescription, and the evidence
/// for domain-targeted cognitive training does not support that — see
/// `lib/moca/activities.dart` for the reasoning. Every domain is shown to every
/// patient, in a fixed order, with the general recommendations attached to each.
///
/// The disclaimer is shown FIRST, above the activities, rather than as a
/// footnote. A reader who stops halfway down the page has still read it.
class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('กิจกรรมที่ช่วยกระตุ้นสมอง', 'Activities'),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
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
              _GeneralCard(),
              const SizedBox(height: 16),
              // A heading that says "engages", not "improves". The wording
              // matters as much as the content: the page must not promise a
              // gain the evidence does not support.
              Text(
                t('กิจกรรมตามด้านต่าง ๆ ของการรู้คิด',
                    'Activities by cognitive domain'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              for (final domain in kActivityDomains) ...[
                _DomainCard(domain: domain),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The required framing, at the top of the page.
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
                    t('โปรดอ่านก่อน', 'Please read first'),
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
            for (final line in requiredFraming)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $line', style: const TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The general recommendations, given their own card above the domains because
/// they carry the strongest evidence on the page.
class _GeneralCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('คำแนะนำสำหรับทุกคน', 'For everyone'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              t('ข้อเหล่านี้มีหลักฐานสนับสนุนมากที่สุด',
                  'These have the strongest evidence behind them.'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            for (final item in generalRecommendations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final ActivityDomain domain;

  const _DomainCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    final note = domain.note;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              domain.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final activity in domain.activities)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(activity, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

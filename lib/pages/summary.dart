import 'package:flutter/material.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/subtests.dart';
import 'package:moca_main/scoring/session_total.dart';
import 'score.dart';

class EndPage extends StatelessWidget {
  const EndPage({super.key});


  @override
  Widget build(BuildContext context) {
    final total = computeSessionTotal(
      larkScore: larkScore,
      clockScore: clockScore,
      animalScore: animalScore,
      attentionScore: attentionScore,
      reorderScore: reorderScore,
      voiceOutcomes: voiceOutcomes,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t("ผลการทดสอบ", "Test Results"),
          style: const TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        elevation: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Result Card
                  _buildResultCard(
                    title: t("ผลการทดสอบเบื้องต้น", "Preliminary Result"),
                    content: total.category == null
                        ? t("ไม่สามารถประเมินได้ เนื่องจากมีแบบทดสอบที่ถูกข้าม",
                            "Could not be assessed because some tests were skipped")
                        : t("คุณเป็น: ${total.category}",
                            "Result: ${categoryLabel(total.category!)}"),
                    contentColor: _getResultColor(total),
                    icon: _getResultIcon(total),
                  ),

                  const SizedBox(height: 20),

                  // Criteria Card
                  _buildInfoCard(
                    title: t("เกณฑ์การประเมิน (เต็ม 30 คะแนน):", "Scoring criteria (out of 30):"),
                    items: [
                      t("26-30: ปกติ", "26-30: Normal"),
                      t("18-25: บกพร่องเล็กน้อย", "18-25: Mild impairment"),
                      t("10-17: มีความบกพร่อง", "10-17: Impaired"),
                      t("0-9: เสี่ยงสูง - ควรเข้าพบปรึกษาแพทย์", "0-9: High risk - please consult a doctor"),
                      // Stated rather than left implicit: the drawing subtest
                      // is administered on paper by a clinician, so every
                      // patient here is scored one point below the scale.
                      t("หมายเหตุ: แบบทดสอบนี้ยังไม่รวมข้อวาดรูปทรง (1 คะแนน)",
                          "Note: this test does not yet include the shape-copy item (1 point)"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Scores Card
                  _buildScoresCard(
                    title: t("คะแนนการทดสอบของคุณ:", "Your test scores:"),
                    items: [
                      t("แบบทดสอบลากเส้น: $larkScore/1", "Trail making: $larkScore/1"),
                      t("แบบทดสอบนาฬิกา: $clockScore/3", "Clock drawing: $clockScore/3"),
                      t("แบบทดสอบทายชื่อสัตว์: $animalScore/3", "Naming: $animalScore/3"),
                      t("แบบทดสอบลบเลข: $attentionScore/3", "Serial subtraction: $attentionScore/3"),
                      t("แบบทดสอบความจำ: $reorderScore/5", "Memory: $reorderScore/5"),
                      for (final spec in kVoiceSubtests)
                        "${sectionLabel(spec.section)} (${spec.id}): "
                            "${voiceOutcomes[spec.id] == null || voiceOutcomes[spec.id]!.skipped ? t('ข้าม', 'Skipped') : '${voiceOutcomes[spec.id]!.score}/${spec.maxScore}'}",
                    ],
                    totalScore: t("คะแนนรวมทั้งหมด: ${total.score}/${total.maxScore}",
                        "Total score: ${total.score}/${total.maxScore}"),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Restart Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      shadowColor: Colors.blue.withOpacity(0.5),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/homepage');
                    },
                    child: Text(t("ทำแบบทดสอบอีกครั้ง", "Take the test again")),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for result card
  Widget _buildResultCard({required String title, required String content, required Color contentColor, required IconData icon}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: contentColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              content,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for info cards
  Widget _buildInfoCard({required String title, required List<String> items}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                item,
                style: const TextStyle(fontSize: 17),
                textAlign: TextAlign.center,
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  // Helper widget for scores card
  Widget _buildScoresCard({required String title, required List<String> items, required String totalScore}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                item,
                style: const TextStyle(fontSize: 17),
                textAlign: TextAlign.center,
              ),
            )).toList(),
            const SizedBox(height: 12),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              totalScore,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getResultColor(SessionTotal total) {
    if (!total.isComplete) return Colors.grey.shade700;
    if (total.score >= 26) return Colors.green.shade700;
    if (total.score >= 18) return Colors.orange.shade700;
    if (total.score >= 10) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  IconData _getResultIcon(SessionTotal total) {
    if (!total.isComplete) return Icons.help_outline;
    if (total.score >= 26) return Icons.check_circle;
    if (total.score >= 18) return Icons.info;
    if (total.score >= 10) return Icons.warning;
    return Icons.error;
  }
}
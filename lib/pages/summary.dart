import 'package:flutter/material.dart';
import 'score.dart';

int totalScore =
    larkScore + clockScore + animalScore + attentionScore + reorderScore;

class EndPage extends StatelessWidget {
  const EndPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ผลการทดสอบ",
          style: TextStyle(
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
                    title: "ผลการทดสอบเบื้องต้น",
                    content: "คุณเป็น: ${_getResultCategory(totalScore)}",
                    contentColor: _getResultColor(totalScore),
                    icon: _getResultIcon(totalScore),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Criteria Card
                  _buildInfoCard(
                    title: "เกณฑ์การประเมิน:",
                    items: [
                      "13-15: ปกติ",
                      "9-13: บกพร่องเล็กน้อย",
                      "5-9: มีความบกพร่อง",
                      "0-5: เสี่ยงเป็นโรคประสาทเสื่อมสูง - ควรเข้าพบปรึกษาแพทย์",
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Scores Card
                  _buildScoresCard(
                    title: "คะแนนการทดสอบของคุณ:",
                    items: [
                      "แบบทดสอบลากเส้น: $larkScore/1",
                      "แบบทดสอบนาฬิกา: $clockScore/3",
                      "แบบทดสอบทายชื่อสัตว์: $animalScore/3",
                      "แบบทดสอบลบเลข: $attentionScore/3",
                      "แบบทดสอบความจำ: $reorderScore/5",
                    ],
                    totalScore: "คะแนนรวมทั้งหมด: $totalScore/15",
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
                    child: const Text("ทำแบบทดสอบอีกครั้ง"),
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

  String _getResultCategory(int score) {
    if (score >= 13) return "ปกติ";
    if (score >= 9) return "บกพร่องเล็กน้อย";
    if (score >= 5) return "มีความบกพร่อง";
    return "เสี่ยงเป็นโรคประสาทเสื่อมสูง";
  }

  Color _getResultColor(int score) {
    if (score >= 13) return Colors.green.shade700;
    if (score >= 9) return Colors.orange.shade700;
    if (score >= 5) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  IconData _getResultIcon(int score) {
    if (score >= 13) return Icons.check_circle;
    if (score >= 9) return Icons.info;
    if (score >= 5) return Icons.warning;
    return Icons.error;
  }
}
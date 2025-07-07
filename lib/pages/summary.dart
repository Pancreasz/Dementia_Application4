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
            fontWeight: FontWeight.bold,  // Bold text here
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "ผลการทดสอบเบื้องต้น",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "คุณเป็น: ${_getResultCategory(totalScore)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getResultColor(totalScore),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Criteria:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "13-15: ปกติ",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "10-12: มีความบกพร่องเล็กน้อย",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "Below 10: เสี่ยงเป็นโรคประสามเสื่อมสูง - ควรเข้าพบปรึกษาแพทย์",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Your test score:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "แบบทดสอบลากเส้น: $larkScore/1",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "แบบทดสอบนาฬิกา: $clockScore/3",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "แบบทดสอบทายชื่อสัตว์: $animalScore/3",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "แบบทดสอบลบเลข: $attentionScore/3",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "แบบทดสอบความจำ: $reorderScore/5",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        "คะแนนรวมทั้งหมด: $totalScore/15",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/homepage');
                  },
                  child: const Text(
                    "ทำแบบทดสอบอีกครั้ง",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getResultCategory(int score) {
    if (score >= 13) return "ปกติ";
    if (score >= 10) return "มีความบกพร่องเล็กน้อย";
    return "เสี่ยงเป็นโรคประสามเสื่อมสูง";
  }

  Color _getResultColor(int score) {
    if (score >= 13) return Colors.green;
    if (score >= 10) return Colors.orange;
    return Colors.red;
  }
}
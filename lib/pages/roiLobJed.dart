import 'package:flutter/material.dart';
import 'score.dart';

class AttentionTestPage extends StatefulWidget {
  const AttentionTestPage({super.key});

  @override
  State<AttentionTestPage> createState() => _AttentionTestPageState();
}

class _AttentionTestPageState extends State<AttentionTestPage> {
  final List<TextEditingController> _controllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  final List<int> _correctAnswers = [93, 86, 79, 72, 65];

  void _handleSubmit() {
    int score = 0;
    for (int i = 0; i < _controllers.length; i++) {
      final input = int.tryParse(_controllers[i].text);
      if (input != null && input == _correctAnswers[i]) {
        score++;
      }
    }

    if (score >= 4) {
      attentionScore = 3;
    } else if (score < 4 && score >= 2) {
      attentionScore = 2;
    } else if (score == 1) {
      attentionScore = 1;
    } else if (score == 0) {
      attentionScore = 0;
    }

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(
    //       "คุณได้คะแนนทั้งหมด $score / 5 ,และคะแนนt $attentionScore / 3 for test",
    //     ),
    //   ),
    // );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แบบทดสอบลบเลข"),
        backgroundColor: Color.fromARGB(255, 87, 152, 225),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "ให้ทำการลบเลขจาก 100 ครั้งล่ะ 7 เป็นจำนวน 5 ครั้ง แต่ล่ะครั้งให้นำคำตอบใส่ลงในช่องตามลำดับ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _controllers[index],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Blue background color
                foregroundColor: Colors.white, // White text color
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                elevation: 3, // Shadow effect
              ),
              onPressed: () {
                _handleSubmit();
                Navigator.pushNamed(context, '/reorderimages');
              },
              child: const Text("ส่งคำตอบ"),
            ),
          ],
        ),
      ),
    );
  }
}

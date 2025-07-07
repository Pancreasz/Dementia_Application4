import 'package:flutter/material.dart';
import 'score.dart';

void main() {
  runApp(const MaterialApp(home: AnimalMocaTestPage()));
}

class AnimalMocaTestPage extends StatefulWidget {
  const AnimalMocaTestPage({super.key});

  @override
  State<AnimalMocaTestPage> createState() => _AnimalMocaTestPageState();
}

class _AnimalMocaTestPageState extends State<AnimalMocaTestPage> {
  final TextEditingController _controller = TextEditingController();
  final Map<String, String> animalImages = {
    'assets/lion.png': 'สิงโต',
    'assets/camel.png': 'อูฐ',
    'assets/rhino.png': 'แรด',
  };

  late List<MapEntry<String, String>> shuffledAnimals;
  int currentIndex = 0;
  int score = 0;
  bool quizFinished = false;

  @override
  void initState() {
    super.initState();
    _startQuiz();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialog();
    });
  }

  void _startQuiz() {
    shuffledAnimals = animalImages.entries.toList()..shuffle();
    currentIndex = 0;
    score = 0;
    quizFinished = false;
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('วิธีทำแบบทดสอบ'),
        content: const Text('โปรดกรอกชื่อสัตว์ตามรูปที่เห็น'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = shuffledAnimals[currentIndex].value.toLowerCase();

    if (userAnswer == correctAnswer) {
      score++;
    }

    setState(() {
      _controller.clear();
      currentIndex++;
      if (currentIndex >= shuffledAnimals.length) {
        animalScore = score;
        Navigator.pushReplacementNamed(context, '/attention');
        quizFinished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กรอกชื่อสัตว์ให้ถูกต้อง'),
        backgroundColor: const Color.fromARGB(255, 87, 152, 225),
        automaticallyImplyLeading: false,
      ),
      body: quizFinished
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '✅ สำเร็จ!\nคะแนนของคุณ: $score / ${shuffledAnimals.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/attention');
                    },
                    child: const Text('แบบทดสอบถัดไป'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color.fromARGB(255, 158, 158, 158)),
                    ),
                    child: Image.asset(
                      shuffledAnimals[currentIndex].key,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Image not found',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'กรอกชื่อสัตว์ให้ถูกต้อง',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _handleSubmit,
                    child: const Text('ส่งคำตอบ'),
                  ),
                ),
              ],
            ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

import '../moca/app_language.dart';
import '../moca/event_trace.dart';
import '../moca/live_session.dart';
import '../moca/naming_keyboard.dart';
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
  /// The answer being typed. A plain string rather than a TextEditingController
  /// because there is no TextField any more: the in-app keyboard is the only
  /// way in, so the system keyboard — with its autocorrect, its word
  /// prediction and its device-dependent layout — never opens. See
  /// `lib/moca/naming_keyboard.dart`.
  String _answer = '';

  static const Map<String, String> _animalImagesTh = {
    'assets/lion.png': 'สิงโต',
    'assets/camel.png': 'อูฐ',
    'assets/rhino.png': 'แรด',
  };
  static const Map<String, String> _animalImagesEn = {
    'assets/lion.png': 'lion',
    'assets/camel.png': 'camel',
    'assets/rhino.png': 'rhino',
  };
  Map<String, String> get animalImages =>
      AppLanguage.isEnglish ? _animalImagesEn : _animalImagesTh;

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
    _markItemShown();
  }

  /// Raw typing events go to the session trace, never to a metric.
  ///
  /// Everything the improvement plan wants from this subtest — time to first
  /// keypress, inter-key intervals, corrections, whether a wrong answer was a
  /// typo — is a function of these events plus their offsets. Storing "median
  /// inter-key interval 480 ms" instead would make a variance, a mid-word
  /// pause, or a within-item trend unrecoverable, and none of those measures
  /// are validated yet, so all of them will need recomputing.
  void _mark(String type, {Map<String, dynamic> data = const {}}) {
    LiveSession.current?.trace.add('naming', type, data: data);
  }

  /// The origin every typing latency for this item is measured from.
  void _markItemShown() {
    if (currentIndex >= shuffledAnimals.length) return;
    _mark(TraceEventType.itemShown, data: {
      'itemIndex': currentIndex,
      'target': shuffledAnimals[currentIndex].value,
    });
  }

  void _onCharacter(String character) {
    setState(() => _answer += character);
    _mark(TraceEventType.keyPressed, data: {
      'itemIndex': currentIndex,
      'key': character,
      'length': _answer.length,
    });
  }

  void _onBackspace() {
    if (_answer.isEmpty) return;
    // Thai combining marks are separate code points, so removing one UTF-16
    // code unit can leave an orphaned mark. characters-aware trimming would be
    // more correct still; a code-unit trim is right for every character on this
    // keyboard, all of which are single units.
    setState(() => _answer = _answer.substring(0, _answer.length - 1));
    _mark(TraceEventType.keyDeleted, data: {
      'itemIndex': currentIndex,
      'length': _answer.length,
    });
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('วิธีทำแบบทดสอบ', 'How to take the test')),
        content: Text(t('โปรดกรอกชื่อสัตว์ตามรูปที่เห็น', 'Please type the name of the animal shown')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(t('ตกลง', 'OK')),
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    final userAnswer = _answer.trim().toLowerCase();
    final correctAnswer = shuffledAnimals[currentIndex].value.toLowerCase();
    final correct = userAnswer == correctAnswer;

    if (correct) {
      score++;
    }

    // The answer itself is kept, not just whether it matched. "camle" and a
    // blank are both wrong and are not the same finding, and nothing can tell
    // them apart from a score of 2/3.
    _mark(TraceEventType.submitted, data: {
      'itemIndex': currentIndex,
      'answer': _answer,
      'target': shuffledAnimals[currentIndex].value,
      'correct': correct,
    });

    setState(() {
      _answer = '';
      currentIndex++;
      if (currentIndex >= shuffledAnimals.length) {
        animalScore = score;
        unawaited(LiveSession.current?.recordScores() ?? Future.value());
        Navigator.pushReplacementNamed(context, '/digit-span-forward');
        quizFinished = true;
      } else {
        _markItemShown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('กรอกชื่อสัตว์ให้ถูกต้อง', 'Type the correct animal name')),
        backgroundColor: const Color.fromARGB(255, 87, 152, 225),
        automaticallyImplyLeading: false,
      ),
      body: quizFinished
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('✅ สำเร็จ!\nคะแนนของคุณ: $score / ${shuffledAnimals.length}',
                        '✅ Done!\nYour score: $score / ${shuffledAnimals.length}'),
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
                      Navigator.pushNamed(context, '/digit-span-forward');
                    },
                    child: Text(t('แบบทดสอบถัดไป', 'Next test')),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              child: Column(
                children: [
                  // Constrained rather than Expanded: the keyboard is tall, and
                  // an image that grows to fill the space pushes the keys off
                  // the bottom of a phone screen.
                  Container(
                    width: double.infinity,
                    height: 200,
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
                  const SizedBox(height: 12),
                  // The answer, displayed rather than edited. A TextField here
                  // would open the system keyboard on top of this one, and with
                  // it autocorrect and Thai word prediction — which on this
                  // subtest can supply the very word being tested.
                  Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blue.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _answer.isEmpty
                          ? t('พิมพ์ชื่อสัตว์', 'Type the animal\'s name')
                          : _answer,
                      style: TextStyle(
                        fontSize: 24,
                        color: _answer.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  NamingKeyboard(
                    onCharacter: _onCharacter,
                    onBackspace: _onBackspace,
                  ),
                  const SizedBox(height: 16),
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
                    onPressed: _handleSubmit,
                    child: Text(t('ส่งคำตอบ', 'Submit')),
                  ),
                ],
              ),
            ),
    );
  }
}
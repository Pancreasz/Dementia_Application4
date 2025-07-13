import 'package:flutter/material.dart';
import 'score.dart';

void resetScores() {
  animalScore = 0;
  larkScore = 0;
  clockScore = 0;
  totalScore = 0;
  attentionScore = 0;
  reorderScore = 0;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'แบบทดสอบโรคประสาทเสื่อม',
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Colors.blue[800], // Added color to text
              ),
            ),
            const SizedBox(height: 30), // Increased spacing
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Button color
                foregroundColor: Colors.white, // Text color
                padding: const EdgeInsets.symmetric(
                  horizontal: 32, 
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                ),
                elevation: 5, // Shadow
              ),
              onPressed: () {
                resetScores();
                Navigator.pushNamed(context, '/larksen');
              },
              child: const Text(
                "เริ่มทำแบบทดสอบ",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
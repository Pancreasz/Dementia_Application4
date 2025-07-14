import 'package:flutter/material.dart';
import 'dart:math';

import 'package:moca_main/pages/score.dart';

void main() {
  runApp(const LineConnectionGame());
}

class LineConnectionGame extends StatelessWidget {
  const LineConnectionGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameScreen();
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Offset> checkpoints = [];
  List<List<Offset>> drawnLines = [];
  bool isChecking = false;
  bool? gameResult;
  final Random random = Random();
  bool isDrawing = false;
  List<Offset> currentLine = [];
  bool showInstructions = true;

  final List<String> checkpointLabels = [
    '1',
    'ก',
    '2',
    'ข',
    '3',
    'ค',
    '4',
    'ง',
    '5',
    'จ',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateCheckpoints();
      _showInstructionsDialog();
    });
  }

  void _generateCheckpoints() {
    final size = MediaQuery.of(context).size;
    const minDistanceFromEdge = 60.0; // Reduced from 80
    const minDistanceBetweenPoints = 70.0; // Reduced from 90
    const pointRadius = 20.0;

    checkpoints.clear();

    for (int i = 0; i < 10; i++) {
      Offset newPoint;
      bool validPosition = false;
      int attempts = 0;
      const maxAttempts = 100;

      while (!validPosition && attempts < maxAttempts) {
        newPoint = Offset(
          minDistanceFromEdge +
              pointRadius +
              random.nextDouble() *
                  (size.width - 2 * (minDistanceFromEdge + pointRadius)),
          minDistanceFromEdge +
              pointRadius +
              random.nextDouble() *
                  (size.height - 2 * (minDistanceFromEdge + pointRadius)),
        );

        validPosition = true;

        // Check distance from edges
        if (newPoint.dx < minDistanceFromEdge + pointRadius ||
            newPoint.dx > size.width - minDistanceFromEdge - pointRadius ||
            newPoint.dy < minDistanceFromEdge + pointRadius ||
            newPoint.dy > size.height - minDistanceFromEdge - pointRadius) {
          validPosition = false;
          attempts++;
          continue;
        }

        // Check distance from other points
        for (var point in checkpoints) {
          if ((point - newPoint).distance < minDistanceBetweenPoints) {
            validPosition = false;
            break;
          }
        }

        if (validPosition) {
          checkpoints.add(newPoint);
        }
        attempts++;
      }

      // If we couldn't find a valid position after maxAttempts, just place it somewhere
      if (!validPosition && attempts >= maxAttempts) {
        newPoint = Offset(
          size.width / 2 +
              (i % 2 == 0 ? -1 : 1) * (minDistanceBetweenPoints * (i ~/ 2 + 1)),
          size.height / 2 +
              (i % 3 == 0 ? -1 : 1) * (minDistanceBetweenPoints * (i ~/ 3 + 1)),
        );
        checkpoints.add(newPoint);
      }
    }
  }

  void _checkSolution() {
    setState(() {
      isChecking = true;
    });

    bool linesCross = _checkLineCrossings();
    if (linesCross) {
      setState(() {
        gameResult = false;
        isChecking = false;
      });
      _showResultDialog(false);
      return;
    }

    bool correctSolution = _validateCompleteSolution();

    setState(() {
      gameResult = correctSolution;
      isChecking = false;
    });

    _showResultDialog(gameResult!);
  }

  bool _validateCompleteSolution() {
    if (!_checkCheckpointSequence()) {
      return false;
    }
    return _validateNoExtraConnections();
  }

  bool _validateNoExtraConnections() {
    Set<String> validConnections = {};
    for (int i = 0; i < checkpoints.length - 1; i++) {
      validConnections.add('$i-${i + 1}');
    }

    for (var line in drawnLines) {
      List<int> connectedIndices = [];
      for (int i = 0; i < checkpoints.length; i++) {
        if ((line.first - checkpoints[i]).distance < 30 ||
            (line.last - checkpoints[i]).distance < 30) {
          connectedIndices.add(i);
        }
      }

      if (connectedIndices.length == 2) {
        int from = connectedIndices[0];
        int to = connectedIndices[1];
        String connection = from < to ? '$from-$to' : '$to-$from';
        if ((from - to).abs() != 1 || !validConnections.contains(connection)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _checkLineCrossings() {
    for (var line in drawnLines) {
      for (int i = 0; i < line.length - 3; i++) {
        for (int j = i + 2; j < line.length - 1; j++) {
          if (!_isNearCheckpoint(line[i]) &&
              !_isNearCheckpoint(line[i + 1]) &&
              !_isNearCheckpoint(line[j]) &&
              !_isNearCheckpoint(line[j + 1]) &&
              _doLinesCross(line[i], line[i + 1], line[j], line[j + 1])) {
            return true;
          }
        }
      }
    }

    for (int i = 0; i < drawnLines.length; i++) {
      for (int j = i + 1; j < drawnLines.length; j++) {
        for (int k = 0; k < drawnLines[i].length - 1; k++) {
          for (int l = 0; l < drawnLines[j].length - 1; l++) {
            if (!_isNearCheckpoint(drawnLines[i][k]) &&
                !_isNearCheckpoint(drawnLines[i][k + 1]) &&
                !_isNearCheckpoint(drawnLines[j][l]) &&
                !_isNearCheckpoint(drawnLines[j][l + 1]) &&
                _doLinesCross(
                  drawnLines[i][k],
                  drawnLines[i][k + 1],
                  drawnLines[j][l],
                  drawnLines[j][l + 1],
                )) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _checkCheckpointSequence() {
    List<bool> connected = List.filled(checkpoints.length, false);
    int currentTarget = 0;

    for (var line in drawnLines) {
      if (currentTarget < checkpoints.length &&
          (line.first - checkpoints[currentTarget]).distance > 30) {
        continue;
      }

      for (
        int nextTarget = currentTarget + 1;
        nextTarget < checkpoints.length;
        nextTarget++
      ) {
        if ((line.last - checkpoints[nextTarget]).distance < 30) {
          connected[currentTarget] = true;
          connected[nextTarget] = true;
          currentTarget = nextTarget;
          break;
        }
      }
    }

    for (int i = 0; i < checkpoints.length; i++) {
      if (!connected[i]) return false;
    }
    return true;
  }

  bool _isNearCheckpoint(Offset point) {
    for (var cp in checkpoints) {
      if ((point - cp).distance < 30) {
        return true;
      }
    }
    return false;
  }

  bool _doLinesCross(Offset a1, Offset a2, Offset b1, Offset b2) {
    double d1 = _direction(b1, b2, a1);
    double d2 = _direction(b1, b2, a2);
    double d3 = _direction(a1, a2, b1);
    double d4 = _direction(a1, a2, b2);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    if (d1 == 0 && _onSegment(b1, b2, a1)) return true;
    if (d2 == 0 && _onSegment(b1, b2, a2)) return true;
    if (d3 == 0 && _onSegment(a1, a2, b1)) return true;
    if (d4 == 0 && _onSegment(a1, a2, b2)) return true;

    return false;
  }

  double _direction(Offset a, Offset b, Offset c) {
    return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  }

  bool _onSegment(Offset a, Offset b, Offset c) {
    return (c.dx >= min(a.dx, b.dx) &&
        c.dx <= max(a.dx, b.dx) &&
        c.dy >= min(a.dy, b.dy) &&
        c.dy <= max(a.dy, b.dy));
  }

  void _showResultDialog(bool passed) {
    if (passed) {
      larkScore = 1;
    } else {
      larkScore = 0;
    }
    Navigator.pushNamed(context, '/clock');
    // showDialog(
    //   context: context,
    //   builder:
    //       (context) => AlertDialog(
    //         title: Text(passed ? '' : ''),
    //         content: Text(
    //           passed
    //               ? 'กด "ตกลง" เพื่อไปแบบทดสอบต่อไป'
    //               : 'กด "ตกลง" เพื่อไปแบบทดสอบต่อไป',
    //         ),
    //         actions: [
    //           TextButton(
    //             child: const Text('ตกลง'),
    //             onPressed: () {
    //               if (passed) {
    //                 larkScore = 1;
    //               } else {
    //                 larkScore = 0;
    //               }
    //               Navigator.pushNamed(context, '/clock');
    //             },
    //           ),
    //         ],
    //       ),
    // );
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'วิธีทำแบบทดสอบ',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add the GIF at the top
              Center(
                child: Image.asset(
                  'assets/larksen_tutorial.gif', // Make sure this path matches your actual GIF location
                  height: 150, // Adjust height as needed
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              _buildInstructionRow('1. ต่อจุดทั้งหมดตามลำดับที่ถูกต้อง'),
              const Padding(
                padding: EdgeInsets.only(left: 24.0, top: 4.0),
                child: Text(
                  'ตัวอย่าง: 1 → ก → 2 → ... → จ',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
              _buildInstructionRow('2. ห้ามลากเส้นทับกัน'),
              const SizedBox(height: 12),
              _buildInstructionRow('3. เมื่อลากเส้นเชื่อมจุดแล้วกรุณายกนิ้วขึ้นแล้วลากเส้นต่อไป'),
              const SizedBox(height: 12),
              _buildInstructionRow(
                '4. ถ้าหากจุดสีฟ้านั้นออกไปนอกหน้าจอ หรือ หลุดขอบให้กดเริ่มใหม่จนกว่าจุดทั้งหมดจะอยู่ในจอ',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'เริ่มแบบทดสอบ',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  showInstructions = false;
                });
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  void _resetGame() {
    setState(() {
      drawnLines.clear();
      currentLine.clear();
      gameResult = null;
      isDrawing = false;
      _generateCheckpoints();
      _showInstructionsDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ตัวอย่าง 1 -> ก -> 2',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 87, 152, 225),
        elevation: 10,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _resetGame,
              child: const Text(
                'เริ่มใหม่',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isChecking ? null : _checkSolution,
              child: const Text(
                'ส่งคำตอบ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onPanStart: (DragStartDetails details) {
              if (showInstructions) return;
              setState(() {
                isDrawing = true;
                currentLine = [details.localPosition];
              });
            },
            onPanUpdate: (DragUpdateDetails details) {
              if (showInstructions) return;
              setState(() {
                currentLine.add(details.localPosition);
              });
            },
            onPanEnd: (DragEndDetails details) {
              if (showInstructions) return;
              setState(() {
                isDrawing = false;
                if (currentLine.length > 1) {
                  drawnLines.add(List.from(currentLine));
                }
                currentLine = [];
              });
            },
            child: CustomPaint(
              painter: LinePainter(
                drawnLines: drawnLines,
                currentLine: currentLine,
              ),
              child: Container(),
            ),
          ),
          CustomPaint(
            painter: CheckpointPainter(
              checkpoints: checkpoints,
              checkpointLabels: checkpointLabels,
            ),
          ),
          if (isChecking) const Center(child: CircularProgressIndicator()),
          if (gameResult != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  gameResult! ? '' : '',
                  style: TextStyle(
                    color: gameResult! ? Colors.green : Colors.red,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final List<List<Offset>> drawnLines;
  final List<Offset> currentLine;

  const LinePainter({required this.drawnLines, required this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    for (var line in drawnLines) {
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], linePaint);
      }
    }

    if (currentLine.isNotEmpty) {
      for (int i = 0; i < currentLine.length - 1; i++) {
        // ignore: deprecated_member_use
        canvas.drawLine(
          currentLine[i],
          currentLine[i + 1],
          linePaint..color = Colors.blue.withOpacity(0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CheckpointPainter extends CustomPainter {
  final List<Offset> checkpoints;
  final List<String> checkpointLabels;

  const CheckpointPainter({
    required this.checkpoints,
    required this.checkpointLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    final subtitleStyle = TextStyle(
      color: Colors.blue[800],
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < checkpoints.length; i++) {
      final checkpoint = checkpoints[i];

      canvas.drawCircle(checkpoint, 20, Paint()..color = Colors.blue);

      final labelPainter = TextPainter(
        text: TextSpan(text: checkpointLabels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        checkpoint - Offset(labelPainter.width / 2, labelPainter.height / 2),
      );

      if (i == 0) {
        final startPainter = TextPainter(
          text: TextSpan(text: 'เริ่มต้น', style: subtitleStyle),
          textDirection: TextDirection.ltr,
        );
        startPainter.layout();
        startPainter.paint(
          canvas,
          checkpoint + Offset(-startPainter.width / 2, 30),
        );
      } else if (i == checkpoints.length - 1) {
        final endPainter = TextPainter(
          text: TextSpan(text: 'สิ้นสุด', style: subtitleStyle),
          textDirection: TextDirection.ltr,
        );
        endPainter.layout();
        endPainter.paint(
          canvas,
          checkpoint + Offset(-endPainter.width / 2, 30),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'score.dart' as globals;

class ReorderImagesPage extends StatefulWidget {
  @override
  _ReorderImagesPageState createState() => _ReorderImagesPageState();
}

class _ReorderImagesPageState extends State<ReorderImagesPage> {
  late List<String> availableImages;
  List<String?> selectedImages = List.filled(5, null);
  final double imageSize = 80.0;
  final double dropBoxSize = 80.0;

  @override
  void initState() {
    super.initState();
    availableImages = List.generate(
      10,
      (index) => 'assets/img${index + 1}.jpg',
    );
    availableImages.shuffle();
  }

  void _onImageDrop(int index, String image) {
    setState(() {
      if (!selectedImages.contains(image)) {
        availableImages.remove(image);
      }

      if (selectedImages[index] != null) {
        availableImages.add(selectedImages[index]!);
      }

      selectedImages[index] = image;
    });
  }

  void _removeImage(int index) {
    setState(() {
      availableImages.add(selectedImages[index]!);
      selectedImages[index] = null;
    });
  }

  bool _canSubmit() => selectedImages.every((img) => img != null);

  void _submitAnswers() {
    // Calculate score without showing dialog
    int score = 0;
    List<String> correctOrder = globals.correctOrder;

    for (int i = 0; i < 5; i++) {
      if (selectedImages[i] == correctOrder[i]) {
        score++;
      }
    }
    globals.reorderScore = score;
    
    // Navigate directly to end page
    Navigator.pushNamed(context, '/endpage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('เรียงลำดับรูปภาพ')),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'รูปภาพทั้งหมด:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: availableImages.map((img) {
                    return Draggable<String>(
                      data: img,
                      feedback: Image.asset(img, width: imageSize),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Image.asset(img, width: imageSize),
                      ),
                      child: Image.asset(img, width: imageSize),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'ลากรูปภาพมาเรียงลำดับให้ถูกต้อง:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxesPerRow = (constraints.maxWidth / (dropBoxSize + 24)).floor();
                    final rowCount = (5 / boxesPerRow).ceil();
                    
                    return Column(
                      children: List.generate(rowCount, (rowIndex) {
                        final start = rowIndex * boxesPerRow;
                        final itemsInRow = (5 - start) > boxesPerRow ? boxesPerRow : 5 - start;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(itemsInRow, (index) {
                              final itemIndex = start + index;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: dropBoxSize,
                                    height: dropBoxSize,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    child: DragTarget<String>(
                                      onAccept: (data) => _onImageDrop(itemIndex, data),
                                      builder: (context, _, __) {
                                        final img = selectedImages[itemIndex];
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: img != null ? Image.asset(img) : null,
                                        );
                                      },
                                    ),
                                  ),
                                  if (selectedImages[itemIndex] != null)
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 20),
                                      onPressed: () => _removeImage(itemIndex),
                                    ),
                                ],
                              );
                            }),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit() ? Colors.blue : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  onPressed: _canSubmit() ? _submitAnswers : null,
                  child: Text('ส่งคำตอบ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
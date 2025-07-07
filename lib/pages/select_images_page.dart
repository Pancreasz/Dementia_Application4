import 'package:flutter/material.dart';
import 'score.dart' as globals;

class SelectImagesPage extends StatefulWidget {
  @override
  _SelectImagesPageState createState() => _SelectImagesPageState();
}

class _SelectImagesPageState extends State<SelectImagesPage> {
  final List<String> allImages = List.generate(
    10,
    (index) => 'assets/img${index + 1}.jpg',
  );
  late List<String> availableImages;
  List<String?> selectedImages = List.filled(5, null);
  final double imageSize = 80.0; // Fixed size for selectable images
  final double dropBoxSize = 80.0; // Fixed size for drop boxes
  
  @override
  void initState() {
    super.initState();
    availableImages = List.from(allImages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInstructionsDialog();
    });
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('คำแนะนำในการทำแบบทดสอบ')),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '1. เลือกรูปภาพ 5 รูปจากทั้งหมด 10 รูป',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  '2. เรียงรูปภาพแบบใดก็ได้ในช่องที่เตรียมไว้',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text('3. จำรูปภาพและลำดับให้ดี', textAlign: TextAlign.center),
                SizedBox(height: 10),
                Text(
                  '4. ในแบบทดสอบภายหลัง ให้เรียงรูปภาพให้ตรงกับที่คุณจำไว้',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  'คุณจะได้คะแนนตามจำนวนรูปภาพที่เรียงถูกต้อง! \n ถ้าหากช่องสี่เหลี่ยมไม่ครบกรุณาเอียงจอเป็นแนวนอน',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            Center(
              child: ElevatedButton(
                child: Text('เริ่มแบบทดสอบ'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
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

  bool _canProceed() => selectedImages.every((img) => img != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'ถ้าหากช่องสี่เหลี่ยมไม่ครบ 5 ช่องกรุณาเอียงจอเป็นแนวนอน', 
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(10),
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
                'ลากรูปภาพ 5 รูปมาวางที่นี่:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate how many boxes we can fit in a row
                    final boxesPerRow = (constraints.maxWidth / (dropBoxSize + 20)).floor();
                    final rowCount = (5 / boxesPerRow).ceil();
                    
                    return Column(
                      children: List.generate(rowCount, (rowIndex) {
                        final start = rowIndex * boxesPerRow;
                        final end = (rowIndex + 1) * boxesPerRow;
                        final itemsInRow = 5 - start > boxesPerRow ? boxesPerRow : 5 - start;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
                                    margin: EdgeInsets.symmetric(horizontal: 5),
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
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed() ? Colors.blue : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _canProceed()
                      ? () {
                          globals.correctOrder = selectedImages.cast<String>();
                          Navigator.pushNamed(context, '/animal');
                        }
                      : null,
                  child: Text('ต่อไป'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
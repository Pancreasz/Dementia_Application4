import 'package:flutter_test/flutter_test.dart';

import 'package:moca_main/main.dart';

void main() {
  testWidgets('home page shows the test title and a start button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('แบบทดสอบโรคประสาทเสื่อม'), findsOneWidget);
    expect(find.text('เริ่มทำแบบทดสอบ'), findsOneWidget);
  });
}

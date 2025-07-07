import 'package:flutter/material.dart';
import 'package:moca_main/pages/animal.dart';
import 'package:moca_main/pages/clock.dart';
import 'package:moca_main/pages/home.dart';
import 'package:moca_main/pages/larksen.dart';
import 'package:moca_main/pages/reorder_images_page.dart';
import 'package:moca_main/pages/roiLobJed.dart';
import 'package:moca_main/pages/select_images_page.dart';
import 'package:moca_main/pages/summary.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/homepage': (context) => const HomePage(),
        '/larksen': (context) => const LineConnectionGame(),
        '/clock': (context) => const ClockTestPage(),
        '/animal': (context) => const AnimalMocaTestPage(),
        '/attention': (context) => const AttentionTestPage(),
        '/selectimages': (context) => SelectImagesPage(),
        '/reorderimages': (context) => ReorderImagesPage(),
        '/endpage': (context) => const EndPage(),
      },
    );
  }
}

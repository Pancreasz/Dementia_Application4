library score;

import 'package:moca_main/scoring/subtest_outcome.dart';

//score variables
int animalScore = 0;
int larkScore = 0;
int clockScore = 0;
int totalScore = 0;
int attentionScore = 0;
int reorderScore = 0;

//images order list
List<String> correctOrder = [];

// The nine voice/tap subtests record here rather than as individual ints,
// because unlike the original five they can be SKIPPED — a state an int cannot
// represent. summary.dart reads both.
Map<String, SubtestOutcome> voiceOutcomes = {};

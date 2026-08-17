import 'package:flutter/material.dart';

import 'subtests.dart';
import 'voice_subtest_page.dart';

/// Routes are derived from subtest ids so the two cannot drift apart.
String routeFor(String subtestId) => '/$subtestId';

/// Where each subtest hands off. Two entries point at existing pages:
/// vigilance hands off to Serial 7s, and abstraction-2 to Delayed Recall.
/// MoCA groups Digit Span and Vigilance with Serial 7s under Attention, and
/// puts Orientation last, after Delayed Recall.
const Map<String, String> _nextRoute = {
  'digit-span-forward': '/digit-span-backward',
  'digit-span-backward': '/vigilance',
  'vigilance': '/attention',
  'sentence-repetition-1': '/sentence-repetition-2',
  'sentence-repetition-2': '/verbal-fluency',
  'verbal-fluency': '/abstraction-1',
  'abstraction-1': '/abstraction-2',
  'abstraction-2': '/reorderimages',
  'orientation': '/endpage',
};

String nextRouteAfter(String subtestId) {
  final next = _nextRoute[subtestId];
  if (next == null) {
    throw ArgumentError('No next route registered for subtest "$subtestId"');
  }
  return next;
}

Map<String, WidgetBuilder> voiceSubtestRoutes() => {
      for (final spec in kVoiceSubtests)
        routeFor(spec.id): (_) => VoiceSubtestPage(
              spec: spec,
              nextRoute: nextRouteAfter(spec.id),
            ),
    };

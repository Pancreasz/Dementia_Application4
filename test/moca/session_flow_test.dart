import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/routes.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  test('every subtest has a route', () {
    final routes = voiceSubtestRoutes();
    for (final spec in kVoiceSubtests) {
      expect(routes.containsKey(routeFor(spec.id)), isTrue, reason: spec.id);
    }
  });

  test('routes are derived from ids, so they cannot drift apart', () {
    expect(routeFor('digit-span-forward'), '/digit-span-forward');
    expect(routeFor('orientation'), '/orientation');
  });

  // The order the session runs in. Serial 7s and Delayed Recall are existing
  // pages, so the chain deliberately hands off to and returns from them.
  test('the chain threads through the two existing pages', () {
    expect(nextRouteAfter('vigilance'), '/attention');
    expect(nextRouteAfter('verbal-fluency'), '/abstraction-1');
    expect(nextRouteAfter('abstraction-2'), '/reorderimages');
    expect(nextRouteAfter('orientation'), '/endpage');
  });

  test('the first three run back to back', () {
    expect(nextRouteAfter('digit-span-forward'), '/digit-span-backward');
    expect(nextRouteAfter('digit-span-backward'), '/vigilance');
  });

  test('sentence repetition runs after serial 7s', () {
    expect(nextRouteAfter('sentence-repetition-1'), '/sentence-repetition-2');
    expect(nextRouteAfter('sentence-repetition-2'), '/verbal-fluency');
  });
}

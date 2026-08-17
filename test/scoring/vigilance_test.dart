import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/scoring/subtest_outcome.dart';
import 'package:moca_main/scoring/vigilance.dart';

void main() {
  // A short stand-in sequence keeps the arithmetic checkable by eye. The real
  // 29-digit sequence is exercised through the spec test in Task 15.
  //   index: 0    1    2    3    4
  //          5    1    3    1    9
  const sequence = '51319';

  SubtestOutcome score(List<int> taps) => scoreVigilance(
        taps,
        sequence: sequence,
        target: '1',
        intervalMs: 1000,
      );

  // Mid-window, so a tap is unambiguous about which digit it belongs to.
  int inWindow(int index) => index * 1000 + 500;

  test('scores 1 when every target is tapped and nothing else is', () {
    final r = score([inWindow(1), inWindow(3)]);
    expect(r.score, 1);
    expect(r.maxScore, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['misses'], 0);
    expect(r.detail['falseTaps'], 0);
  });

  test('still scores 1 with a single missed target — the rule allows one error', () {
    final r = score([inWindow(1)]);
    expect(r.score, 1);
    expect(r.detail['misses'], 1);
    expect(r.detail['errors'], 1);
  });

  test('scores 0 once there are two errors', () {
    final r = score([]);
    expect(r.score, 0);
    expect(r.detail['misses'], 2);
    expect(r.detail['errors'], 2);
  });

  test('counts a tap on a non-target digit as a false tap', () {
    final r = score([inWindow(1), inWindow(3), inWindow(4)]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['falseTaps'], 1);
  });

  test('scores 0 for one miss plus one false tap', () {
    final r = score([inWindow(1), inWindow(0)]);
    expect(r.score, 0);
    expect(r.detail['errors'], 2);
  });

  // The instrument counts errors per digit, not per hand movement: a patient
  // who double-taps one target has made one mistake about one digit.
  test('counts two taps inside one window as a single event', () {
    final r = score([inWindow(1), inWindow(1) + 100, inWindow(3)]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['errors'], 0);
  });

  // The deliberate cost of strict windows, locked in so it can never change
  // silently: a reaction slower than the interval is charged twice.
  test('charges a late tap as both a miss and a false tap', () {
    final r = score([1000 + 1100]);
    expect(r.score, 0);
    expect(r.detail['misses'], 2);
    expect(r.detail['falseTaps'], 1);
    expect(r.detail['errors'], 3);
  });

  test('ignores taps before the first digit or after the last window', () {
    final r = score([-200, inWindow(1), inWindow(3), 5 * 1000 + 10]);
    expect(r.score, 1);
    expect(r.detail['hits'], 2);
    expect(r.detail['falseTaps'], 0);
  });

  test('measures each latency from its own target onset', () {
    final r = score([1000 + 420, 3000 + 610]);
    expect(r.detail['tapLatencies'], [420, 610]);
  });

  test('reports latency for the first tap in a window when there are several', () {
    final r = score([1000 + 300, 1000 + 800, 3000 + 500]);
    expect(r.detail['tapLatencies'], [300, 500]);
  });
}

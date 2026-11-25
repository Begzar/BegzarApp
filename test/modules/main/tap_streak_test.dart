import 'package:begzar/modules/main/presentation/tap_streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('should open on the seventh quick tap and not before', () {
    final streak = TapStreak();
    for (var i = 0; i < 6; i++) {
      expect(streak.tap(at(i * 300)), isFalse, reason: 'tap ${i + 1}');
    }
    expect(streak.tap(at(6 * 300)), isTrue);
  });

  test('should start again after a pause', () {
    final streak = TapStreak();
    for (var i = 0; i < 5; i++) {
      streak.tap(at(i * 300));
    }
    // A pause longer than the gap: this tap is the first of a new streak.
    var now = 5 * 300 + 2000;
    expect(streak.tap(at(now)), isFalse);
    for (var i = 0; i < 5; i++) {
      now += 300;
      expect(streak.tap(at(now)), isFalse);
    }
    expect(streak.tap(at(now + 300)), isTrue);
  });

  test('should need a whole new streak after opening', () {
    final streak = TapStreak();
    for (var i = 0; i < 7; i++) {
      streak.tap(at(i * 100));
    }
    expect(streak.tap(at(800)), isFalse);
  });
}

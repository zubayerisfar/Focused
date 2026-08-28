import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/productivity_streak_service.dart';

void main() {
  const service = ProductivityStreakService();

  test('empty activity has zero streak', () {
    expect(
      service.calculateCurrentStreak(
        now: DateTime(2026, 8, 28, 12),
        activityDates: const [],
      ),
      0,
    );
  });

  test('today and previous consecutive days count', () {
    expect(
      service.calculateCurrentStreak(
        now: DateTime(2026, 8, 28, 12),
        activityDates: [
          DateTime(2026, 8, 28, 8),
          DateTime(2026, 8, 27, 21),
          DateTime(2026, 8, 26, 10),
        ],
      ),
      3,
    );
  });

  test('unfinished current day preserves streak through yesterday', () {
    expect(
      service.calculateCurrentStreak(
        now: DateTime(2026, 8, 28, 9),
        activityDates: [
          DateTime(2026, 8, 27, 21),
          DateTime(2026, 8, 26, 10),
          DateTime(2026, 8, 25, 18),
        ],
      ),
      3,
    );
  });

  test('gap stops the streak', () {
    expect(
      service.calculateCurrentStreak(
        now: DateTime(2026, 8, 28, 12),
        activityDates: [
          DateTime(2026, 8, 28, 8),
          DateTime(2026, 8, 26, 10),
          DateTime(2026, 8, 25, 10),
        ],
      ),
      1,
    );
  });

  test('multiple activity records on same day count once', () {
    expect(
      service.calculateCurrentStreak(
        now: DateTime(2026, 8, 28, 12),
        activityDates: [
          DateTime(2026, 8, 28, 8),
          DateTime(2026, 8, 28, 18),
          DateTime(2026, 8, 27, 10),
        ],
      ),
      2,
    );
  });
}

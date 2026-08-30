import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/habit_reminder_planner.dart';

void main() {
  const planner = HabitReminderPlanner();

  test('same weekday before reminder time schedules today', () {
    final next = planner.nextForWeekday(
      now: DateTime(2026, 8, 31, 18), // Monday
      weekday: DateTime.monday,
      minutesFromMidnight: 20 * 60,
    );

    expect(next, DateTime(2026, 8, 31, 20));
  });

  test('same weekday after reminder time schedules next week', () {
    final next = planner.nextForWeekday(
      now: DateTime(2026, 8, 31, 21), // Monday
      weekday: DateTime.monday,
      minutesFromMidnight: 20 * 60,
    );

    expect(next, DateTime(2026, 9, 7, 20));
  });

  test('selected weekdays produce one future reminder per selected day', () {
    final result = planner.planSelectedWeekdays(
      now: DateTime(2026, 8, 30, 12), // Sunday
      weekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
      minutesFromMidnight: 8 * 60 + 30,
    );

    expect(result, [
      DateTime(2026, 8, 31, 8, 30),
      DateTime(2026, 9, 2, 8, 30),
      DateTime(2026, 9, 4, 8, 30),
    ]);
  });
}

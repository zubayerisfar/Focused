import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/habit.dart';
import 'package:focused/models/habit_progress.dart';
import 'package:focused/services/habit_analytics_service.dart';

void main() {
  const service = HabitAnalyticsService();

  Habit dailyHabit({DateTime? createdAt}) {
    return Habit(
      id: 'daily',
      title: 'Read',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      createdAt: createdAt ?? DateTime(2026, 8, 24, 8),
    );
  }

  HabitProgress done(DateTime date) {
    return HabitProgress(
      habitId: 'daily',
      date: date,
      value: 1,
      updatedAt: date.add(const Duration(hours: 20)),
    );
  }

  test('unfinished current day does not break an existing streak', () {
    final summary = service.analyze(
      habit: dailyHabit(),
      progress: [
        done(DateTime(2026, 8, 27)),
        done(DateTime(2026, 8, 28)),
        done(DateTime(2026, 8, 29)),
      ],
      asOf: DateTime(2026, 8, 30, 15),
    );

    expect(summary.currentStreak, 3);
    expect(summary.bestStreak, 3);
  });

  test('historical missed scheduled occurrence breaks current streak', () {
    final summary = service.analyze(
      habit: dailyHabit(),
      progress: [
        done(DateTime(2026, 8, 27)),
        done(DateTime(2026, 8, 29)),
      ],
      asOf: DateTime(2026, 8, 30, 15),
    );

    expect(summary.currentStreak, 1);
    expect(summary.bestStreak, 1);
  });

  test('selected weekdays ignore rest days when calculating streak', () {
    final habit = Habit(
      id: 'mwf',
      title: 'Exercise',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      colorValue: const Color(0xFF34B27B).value,
      createdAt: DateTime(2026, 8, 24, 8),
    );

    HabitProgress mwfDone(DateTime date) => HabitProgress(
          habitId: 'mwf',
          date: date,
          value: 1,
          updatedAt: date.add(const Duration(hours: 18)),
        );

    final summary = service.analyze(
      habit: habit,
      progress: [
        mwfDone(DateTime(2026, 8, 24)), // Monday
        mwfDone(DateTime(2026, 8, 26)), // Wednesday
        mwfDone(DateTime(2026, 8, 28)), // Friday
      ],
      asOf: DateTime(2026, 8, 30), // Sunday
    );

    expect(summary.currentStreak, 3);
    expect(summary.scheduledLast7Days, 3);
    expect(summary.completedLast7Days, 3);
    expect(summary.last7DaysCompletionRate, 1.0);
  });

  test('30 day and month rates count scheduled occurrences only', () {
    final habit = Habit(
      id: 'mwf',
      title: 'Exercise',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      colorValue: const Color(0xFF34B27B).value,
      createdAt: DateTime(2026, 8, 1),
    );

    final progress = <HabitProgress>[];
    for (final date in [
      DateTime(2026, 8, 3),
      DateTime(2026, 8, 5),
      DateTime(2026, 8, 7),
      DateTime(2026, 8, 10),
    ]) {
      progress.add(
        HabitProgress(
          habitId: 'mwf',
          date: date,
          value: 1,
          updatedAt: date.add(const Duration(hours: 18)),
        ),
      );
    }

    final summary = service.analyze(
      habit: habit,
      progress: progress,
      asOf: DateTime(2026, 8, 10, 12),
    );

    expect(summary.scheduledThisMonth, 4);
    expect(summary.completedThisMonth, 4);
    expect(summary.monthCompletionRate, 1.0);
  });

  test('period analytics excludes the still-open current day from trend rate', () {
    final habit = dailyHabit(createdAt: DateTime(2026, 8, 27, 8));
    final summary = service.analyzePeriod(
      habits: [habit],
      progress: [
        done(DateTime(2026, 8, 27)),
        done(DateTime(2026, 8, 28)),
        done(DateTime(2026, 8, 29)),
      ],
      startDay: DateTime(2026, 8, 27),
      endDayExclusive: DateTime(2026, 8, 31),
      asOf: DateTime(2026, 8, 30, 15),
    );

    expect(summary.scheduledOccurrences, 3);
    expect(summary.completedOccurrences, 3);
    expect(summary.completionRate, 1.0);
  });

}

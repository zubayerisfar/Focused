import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/habit.dart';
import 'package:focused/models/habit_definition_revision.dart';

void main() {
  Habit buildHabit({
    Set<int> weekdays = const {1, 3, 5},
    int target = 20,
    int? reminderMinutesFromMidnight,
  }) {
    return Habit(
      id: 'habit-1',
      title: 'Read',
      goalType: HabitGoalType.count,
      targetValue: target,
      unit: 'pages',
      weekdays: weekdays,
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      reminderMinutesFromMidnight: reminderMinutesFromMidnight,
      createdAt: DateTime(2026, 8, 29, 8),
    );
  }

  test('habit occurs only on selected weekdays', () {
    final habit = buildHabit();

    expect(habit.occursOn(DateTime(2026, 8, 31)), isTrue); // Monday
    expect(habit.occursOn(DateTime(2026, 9, 1)), isFalse); // Tuesday
    expect(habit.occursOn(DateTime(2026, 9, 2)), isTrue); // Wednesday
  });

  test('habit round-trips through current schema', () {
    final habit = buildHabit();
    final restored = Habit.fromMap(habit.toMap());

    expect(restored.id, habit.id);
    expect(restored.title, habit.title);
    expect(restored.goalType, HabitGoalType.count);
    expect(restored.targetValue, 20);
    expect(restored.weekdays, const {1, 3, 5});
    expect(restored.iconCodePoint, habit.iconCodePoint);
    expect(restored.colorValue, habit.colorValue);
    expect(restored.reminderMinutesFromMidnight, isNull);
  });


  test('habit reminder round-trips and can be cleared with copyWith', () {
    final habit = buildHabit(reminderMinutesFromMidnight: 20 * 60 + 30);
    final restored = Habit.fromMap(habit.toMap());

    expect(restored.reminderMinutesFromMidnight, 1230);
    expect(restored.reminderTime, const TimeOfDay(hour: 20, minute: 30));

    final withoutReminder = restored.copyWith(reminderMinutesFromMidnight: null);
    expect(withoutReminder.reminderMinutesFromMidnight, isNull);
  });

  test('schema v1 habit without reminder remains readable', () {
    final map = buildHabit().toMap()
      ..['schemaVersion'] = 1
      ..remove('reminderMinutesFromMidnight')
      ..remove('definitionEffectiveFromDay')
      ..remove('definitionHistory');

    final restored = Habit.fromMap(map);
    expect(restored.title, 'Read');
    expect(restored.reminderMinutesFromMidnight, isNull);
  });

  test('habit rejects invalid reminder minute-of-day', () {
    expect(
      () => buildHabit(reminderMinutesFromMidnight: 24 * 60),
      throwsArgumentError,
    );
  });


  test('habit definition history round-trips without rewriting old schedule', () {
    final habit = Habit(
      id: 'history',
      title: 'Exercise',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      colorValue: const Color(0xFF34B27B).value,
      createdAt: DateTime(2026, 8, 24, 8),
      definitionEffectiveFromDay: DateTime(2026, 8, 27),
      definitionHistory: [
        HabitDefinitionRevision(
          effectiveFromDay: DateTime(2026, 8, 24),
          effectiveUntilDayExclusive: DateTime(2026, 8, 27),
          targetValue: 1,
          weekdays: const {DateTime.monday, DateTime.wednesday},
        ),
      ],
    );

    final restored = Habit.fromMap(habit.toMap());

    expect(restored.occursOnDate(DateTime(2026, 8, 24)), isTrue);
    expect(restored.occursOnDate(DateTime(2026, 8, 25)), isFalse);
    expect(restored.occursOnDate(DateTime(2026, 8, 27)), isTrue);
    expect(restored.definitionHistory, hasLength(1));
  });

  test('habit requires at least one repeat day', () {
    expect(
      () => buildHabit(weekdays: const {}),
      throwsArgumentError,
    );
  });

  test('habit target must be positive', () {
    expect(
      () => buildHabit(target: 0),
      throwsArgumentError,
    );
  });
}

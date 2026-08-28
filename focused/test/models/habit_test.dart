import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/habit.dart';

void main() {
  Habit buildHabit({
    Set<int> weekdays = const {1, 3, 5},
    int target = 20,
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

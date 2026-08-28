import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/habit.dart';
import 'package:focused/models/habit_progress.dart';
import 'package:focused/providers/habit_provider.dart';
import 'package:focused/services/habit_storage_service.dart';

class _MemoryHabitStore implements HabitStore {
  final Map<String, Habit> habits = {};
  final Map<String, HabitProgress> progress = {};

  @override
  List<Habit> loadHabits() => habits.values.toList();

  @override
  List<HabitProgress> loadProgress() => progress.values.toList();

  @override
  Future<void> saveHabit(Habit habit) async {
    habits[habit.id] = habit;
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    habits.remove(habitId);
    progress.removeWhere((_, value) => value.habitId == habitId);
  }

  @override
  Future<void> saveProgress(HabitProgress item) async {
    progress[item.storageKey] = item;
  }

  @override
  Future<void> deleteProgress(String habitId, DateTime date) async {
    progress.remove(HabitProgress.storageKeyFor(habitId, date));
  }

  @override
  Future<void> deleteProgressForHabit(String habitId) async {
    progress.removeWhere((_, value) => value.habitId == habitId);
  }
}

void main() {
  test('creates a real persisted habit and filters by weekday', () async {
    final store = _MemoryHabitStore();
    final provider = HabitProvider(storageService: store);

    final habit = await provider.createHabit(
      title: 'Read',
      goalType: HabitGoalType.count,
      targetValue: 20,
      unit: 'pages',
      weekdays: const {DateTime.monday, DateTime.wednesday},
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      createdAt: DateTime(2026, 8, 31, 8),
    );

    expect(store.habits.containsKey(habit.id), isTrue);
    expect(provider.habitsForDate(DateTime(2026, 8, 31)), hasLength(1));
    expect(provider.habitsForDate(DateTime(2026, 9, 1)), isEmpty);
  });

  test('progress is date-specific and completion uses target', () async {
    final provider = HabitProvider();
    final habit = await provider.createHabit(
      title: 'Water',
      goalType: HabitGoalType.count,
      targetValue: 8,
      unit: 'cups',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.water_drop_rounded.codePoint,
      colorValue: const Color(0xFF34B27B).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );

    final today = DateTime(2026, 8, 29);
    final tomorrow = DateTime(2026, 8, 30);

    await provider.setProgress(habit.id, today, 7);
    expect(provider.isCompletedForDate(habit, today), isFalse);

    await provider.setProgress(habit.id, today, 8);
    expect(provider.isCompletedForDate(habit, today), isTrue);
    expect(provider.progressForDate(habit.id, tomorrow), 0);
  });

  test('toggle complete does not affect another date', () async {
    final provider = HabitProvider();
    final habit = await provider.createHabit(
      title: 'Exercise',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      colorValue: const Color(0xFF8E67D4).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );

    final first = DateTime(2026, 8, 29);
    final second = DateTime(2026, 8, 30);
    await provider.toggleCompleted(habit.id, first);

    expect(provider.isCompletedForDate(habit, first), isTrue);
    expect(provider.isCompletedForDate(habit, second), isFalse);
  });

  test('stored progress survives provider reload', () async {
    final store = _MemoryHabitStore();
    final firstProvider = HabitProvider(storageService: store);
    final habit = await firstProvider.createHabit(
      title: 'Read',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );
    final date = DateTime(2026, 8, 29);
    await firstProvider.toggleCompleted(habit.id, date);

    final secondProvider = HabitProvider(storageService: store);
    await secondProvider.loadStoredHabits();
    final restored = secondProvider.getHabitById(habit.id)!;

    expect(secondProvider.isCompletedForDate(restored, date), isTrue);
  });

  test('deleting habit removes its progress history', () async {
    final store = _MemoryHabitStore();
    final provider = HabitProvider(storageService: store);
    final habit = await provider.createHabit(
      title: 'Read',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );
    await provider.toggleCompleted(habit.id, DateTime(2026, 8, 29));

    await provider.deleteHabit(habit.id);

    expect(provider.getHabitById(habit.id), isNull);
    expect(store.progress, isEmpty);
  });
}

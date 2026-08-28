import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/habit.dart';
import 'package:focused/models/habit_progress.dart';
import 'package:focused/services/habit_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('focused-habits-');
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('habit and progress survive storage reload', () async {
    final storage = HabitStorageService();
    await storage.init();

    final habit = Habit(
      id: 'habit-1',
      title: 'Read',
      goalType: HabitGoalType.count,
      targetValue: 20,
      unit: 'pages',
      weekdays: const {1, 3, 5},
      iconCodePoint: Icons.menu_book_rounded.codePoint,
      colorValue: const Color(0xFF4D7CFE).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );
    final progress = HabitProgress(
      habitId: habit.id,
      date: DateTime(2026, 8, 31),
      value: 20,
      updatedAt: DateTime(2026, 8, 31, 20),
    );

    await storage.saveHabit(habit);
    await storage.saveProgress(progress);

    expect(storage.loadHabits().single.title, 'Read');
    expect(storage.loadProgress().single.value, 20);
  });

  test('deleting habit clears tied progress', () async {
    final storage = HabitStorageService();
    await storage.init();

    final habit = Habit(
      id: 'habit-delete',
      title: 'Exercise',
      goalType: HabitGoalType.checkIn,
      targetValue: 1,
      unit: 'done',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
      colorValue: const Color(0xFF34B27B).value,
      createdAt: DateTime(2026, 8, 29, 8),
    );
    await storage.saveHabit(habit);
    await storage.saveProgress(
      HabitProgress(
        habitId: habit.id,
        date: DateTime(2026, 8, 29),
        value: 1,
        updatedAt: DateTime(2026, 8, 29, 9),
      ),
    );

    await storage.deleteHabit(habit.id);

    expect(storage.loadHabits(), isEmpty);
    expect(storage.loadProgress(), isEmpty);
  });
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_progress.dart';
import '../services/habit_storage_service.dart';

class HabitProvider extends ChangeNotifier {
  HabitProvider({HabitStore? storageService}) : _storageService = storageService;

  final HabitStore? _storageService;
  final Random _random = Random.secure();

  final List<Habit> _habits = [];
  final List<HabitProgress> _progress = [];

  List<Habit> get habits => List<Habit>.unmodifiable(_habits);

  Future<void> loadStoredHabits() async {
    final storage = _storageService;
    if (storage == null) {
      return;
    }

    _habits
      ..clear()
      ..addAll(storage.loadHabits());

    final knownHabitIds = _habits.map((habit) => habit.id).toSet();
    _progress
      ..clear()
      ..addAll(
        storage.loadProgress().where(
              (item) => knownHabitIds.contains(item.habitId),
            ),
      );

    notifyListeners();
  }

  Habit? getHabitById(String id) {
    for (final habit in _habits) {
      if (habit.id == id) {
        return habit;
      }
    }
    return null;
  }

  Future<Habit> createHabit({
    required String title,
    required HabitGoalType goalType,
    required int targetValue,
    required String unit,
    required Set<int> weekdays,
    required int iconCodePoint,
    required int colorValue,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final habit = Habit(
      id: _generateId(now),
      title: title.trim(),
      goalType: goalType,
      targetValue: targetValue,
      unit: unit.trim(),
      weekdays: weekdays,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      createdAt: now,
    );

    _habits.add(habit);
    notifyListeners();

    try {
      await _storageService?.saveHabit(habit);
    } catch (_) {
      _habits.removeWhere((item) => item.id == habit.id);
      notifyListeners();
      rethrow;
    }

    return habit;
  }

  Future<void> updateHabit(Habit updatedHabit) async {
    final index = _habits.indexWhere((habit) => habit.id == updatedHabit.id);
    if (index == -1) {
      throw StateError('Cannot update a habit that does not exist.');
    }

    final previous = _habits[index];
    _habits[index] = updatedHabit;
    notifyListeners();

    try {
      await _storageService?.saveHabit(updatedHabit);
    } catch (_) {
      _habits[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) {
      return;
    }

    final habit = _habits.removeAt(index);
    final removedProgress = _progress.where((item) => item.habitId == habitId).toList();
    _progress.removeWhere((item) => item.habitId == habitId);
    notifyListeners();

    try {
      await _storageService?.deleteHabit(habitId);
    } catch (_) {
      _habits.insert(index, habit);
      _progress.addAll(removedProgress);
      notifyListeners();
      rethrow;
    }
  }

  List<Habit> habitsForDate(DateTime date) {
    final result = _habits.where((habit) => habit.occursOn(date)).toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<Habit>.unmodifiable(result);
  }

  int progressForDate(String habitId, DateTime date) {
    final day = _dateOnly(date);
    for (final item in _progress) {
      if (item.habitId == habitId && _sameDate(item.date, day)) {
        return item.value;
      }
    }
    return 0;
  }

  bool isCompletedForDate(Habit habit, DateTime date) {
    return progressForDate(habit.id, date) >= habit.targetValue;
  }

  Future<void> setProgress(
    String habitId,
    DateTime date,
    int value, {
    DateTime? updatedAt,
  }) async {
    final habit = getHabitById(habitId);
    if (habit == null) {
      throw StateError('Cannot update a habit that does not exist.');
    }

    final day = _dateOnly(date);
    if (!habit.occursOn(day)) {
      throw StateError('Habit is not scheduled for this date.');
    }

    final clamped = value.clamp(0, habit.targetValue).toInt();
    final existingIndex = _progress.indexWhere(
      (item) => item.habitId == habitId && _sameDate(item.date, day),
    );
    final previous = existingIndex == -1 ? null : _progress[existingIndex];

    if (clamped == 0) {
      if (existingIndex != -1) {
        _progress.removeAt(existingIndex);
        notifyListeners();
      }

      try {
        await _storageService?.deleteProgress(habitId, day);
      } catch (_) {
        if (previous != null) {
          _progress.add(previous);
          notifyListeners();
        }
        rethrow;
      }
      return;
    }

    final progress = HabitProgress(
      habitId: habitId,
      date: day,
      value: clamped,
      updatedAt: updatedAt ?? DateTime.now(),
    );

    if (existingIndex == -1) {
      _progress.add(progress);
    } else {
      _progress[existingIndex] = progress;
    }
    notifyListeners();

    try {
      await _storageService?.saveProgress(progress);
    } catch (_) {
      if (existingIndex == -1) {
        _progress.removeWhere((item) => item.storageKey == progress.storageKey);
      } else if (previous != null) {
        _progress[existingIndex] = previous;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleCompleted(String habitId, DateTime date) async {
    final habit = getHabitById(habitId);
    if (habit == null) {
      throw StateError('Cannot update a habit that does not exist.');
    }

    final completed = isCompletedForDate(habit, date);
    await setProgress(habitId, date, completed ? 0 : habit.targetValue);
  }

  List<HabitProgress> progressForHabit(String habitId) {
    final result = _progress.where((item) => item.habitId == habitId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List<HabitProgress>.unmodifiable(result);
  }

  int completedHabitCountForDate(DateTime date) {
    return habitsForDate(date).where((habit) => isCompletedForDate(habit, date)).length;
  }

  String _generateId(DateTime now) {
    return 'habit_${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

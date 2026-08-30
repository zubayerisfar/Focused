import 'package:hive_ce/hive_ce.dart';

import '../models/habit.dart';
import '../models/habit_progress.dart';

abstract class HabitStore {
  List<Habit> loadHabits();
  List<HabitProgress> loadProgress();
  Future<void> saveHabit(Habit habit);
  Future<void> deleteHabit(String habitId);
  Future<void> saveProgress(HabitProgress progress);
  Future<void> deleteProgress(String habitId, DateTime date);
  Future<void> deleteProgressForHabit(String habitId);
}

class HabitStorageService implements HabitStore {
  static const _habitBoxName = 'focused_habits';
  static const _progressBoxName = 'focused_habit_progress';

  Box<dynamic>? _habitBox;
  Box<dynamic>? _progressBox;

  Future<void> init() async {
    _habitBox ??= await Hive.openBox<dynamic>(_habitBoxName);
    _progressBox ??= await Hive.openBox<dynamic>(_progressBoxName);
  }

  Box<dynamic> get _habits {
    final box = _habitBox;
    if (box == null) {
      throw StateError('HabitStorageService.init() must be called first.');
    }
    return box;
  }

  Box<dynamic> get _progress {
    final box = _progressBox;
    if (box == null) {
      throw StateError('HabitStorageService.init() must be called first.');
    }
    return box;
  }

  @override
  List<Habit> loadHabits() {
    final result = <Habit>[];
    for (final raw in _habits.values) {
      try {
        if (raw is Map) {
          result.add(Habit.fromMap(Map<dynamic, dynamic>.from(raw)));
        }
      } catch (_) {
        // Ignore malformed development records rather than breaking startup.
      }
    }
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  List<HabitProgress> loadProgress() {
    final result = <HabitProgress>[];
    for (final raw in _progress.values) {
      try {
        if (raw is Map) {
          result.add(HabitProgress.fromMap(Map<dynamic, dynamic>.from(raw)));
        }
      } catch (_) {
        // Ignore malformed development records rather than breaking startup.
      }
    }
    return result;
  }

  @override
  Future<void> saveHabit(Habit habit) {
    return _habits.put(habit.id, habit.toMap());
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _habits.delete(habitId);
    await deleteProgressForHabit(habitId);
  }

  @override
  Future<void> saveProgress(HabitProgress progress) {
    return _progress.put(progress.storageKey, progress.toMap());
  }

  @override
  Future<void> deleteProgress(String habitId, DateTime date) {
    return _progress.delete(HabitProgress.storageKeyFor(habitId, date));
  }

  @override
  Future<void> deleteProgressForHabit(String habitId) async {
    final keys = <dynamic>[];
    for (final key in _progress.keys) {
      if (key is String && key.startsWith('${habitId}_')) {
        keys.add(key);
      }
    }
    if (keys.isNotEmpty) {
      await _progress.deleteAll(keys);
    }
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_analytics_summary.dart';
import '../models/habit_definition_revision.dart';
import '../models/habit_progress.dart';
import '../models/habit_period_summary.dart';
import '../models/habit_reminder_result.dart';
import '../services/habit_analytics_service.dart';
import '../services/habit_notification_service.dart';
import '../services/habit_storage_service.dart';

class HabitProvider extends ChangeNotifier {
  HabitProvider({
    HabitStore? storageService,
    HabitReminderScheduler? reminderScheduler,
    HabitAnalyticsService analyticsService = const HabitAnalyticsService(),
  }) : _storageService = storageService,
       _reminderScheduler = reminderScheduler,
       _analyticsService = analyticsService;

  final HabitStore? _storageService;
  final HabitReminderScheduler? _reminderScheduler;
  final HabitAnalyticsService _analyticsService;
  final Random _random = Random.secure();

  final List<Habit> _habits = [];
  final List<HabitProgress> _progress = [];
  HabitReminderScheduleResult? _lastReminderResult;

  List<Habit> get habits => List<Habit>.unmodifiable(_habits);

  HabitReminderScheduleResult? get lastReminderResult => _lastReminderResult;

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

  Set<DateTime> habitCompletionDates() {
    final dates = <DateTime>{};
    for (final habit in _habits) {
      for (final p in _progress) {
        if (p.habitId == habit.id && p.value >= habit.targetValue) {
          dates.add(DateTime(p.date.year, p.date.month, p.date.day));
        }
      }
    }
    return dates;
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
    int? reminderMinutesFromMidnight,
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
      reminderMinutesFromMidnight: reminderMinutesFromMidnight,
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

    await _scheduleReminderSafely(habit);
    return habit;
  }

  Future<void> updateHabit(Habit updatedHabit, {DateTime? updatedAt}) async {
    final index = _habits.indexWhere((habit) => habit.id == updatedHabit.id);
    if (index == -1) {
      throw StateError('Cannot update a habit that does not exist.');
    }

    final previous = _habits[index];
    final normalized = _preserveDefinitionHistory(
      previous: previous,
      updated: updatedHabit,
      changedAt: updatedAt ?? DateTime.now(),
    );

    _habits[index] = normalized;
    notifyListeners();

    try {
      await _storageService?.saveHabit(normalized);
    } catch (_) {
      _habits[index] = previous;
      notifyListeners();
      rethrow;
    }

    await _scheduleReminderSafely(normalized);
  }

  Future<void> deleteHabit(String habitId) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) {
      return;
    }

    final habit = _habits.removeAt(index);
    final removedProgress = _progress
        .where((item) => item.habitId == habitId)
        .toList();
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

    await _cancelReminderSafely(habitId);
  }

  List<Habit> habitsForDate(DateTime date) {
    final result = _habits.where((habit) => habit.occursOnDate(date)).toList();
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
    final target = habit.targetValueForDate(date);
    if (target == null || !habit.occursOnDate(date)) return false;
    return progressForDate(habit.id, date) >= target;
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
    final target = habit.targetValueForDate(day);
    if (target == null || !habit.occursOnDate(day)) {
      throw StateError('Habit is not scheduled for this date.');
    }

    final clamped = value.clamp(0, target).toInt();
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
    final target = habit.targetValueForDate(date);
    if (target == null) {
      throw StateError('Habit does not have a goal for this date.');
    }
    await setProgress(habitId, date, completed ? 0 : target);
  }

  List<HabitProgress> progressForHabit(String habitId) {
    final result = _progress.where((item) => item.habitId == habitId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List<HabitProgress>.unmodifiable(result);
  }

  HabitAnalyticsSummary analyticsForHabit(String habitId, {DateTime? asOf}) {
    final habit = getHabitById(habitId);
    if (habit == null) {
      throw StateError('Cannot analyze a habit that does not exist.');
    }
    return analyticsFor(habit, asOf: asOf);
  }

  HabitAnalyticsSummary analyticsFor(Habit habit, {DateTime? asOf}) {
    return _analyticsService.analyze(
      habit: habit,
      progress: progressForHabit(habit.id),
      asOf: asOf,
    );
  }

  HabitPeriodSummary analyticsForPeriod({
    required DateTime startDay,
    required DateTime endDayExclusive,
    DateTime? asOf,
  }) {
    return _analyticsService.analyzePeriod(
      habits: habits,
      progress: List<HabitProgress>.unmodifiable(_progress),
      startDay: startDay,
      endDayExclusive: endDayExclusive,
      asOf: asOf,
    );
  }

  Future<int> pendingReminderCountForHabit(String habitId) async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) return 0;
    try {
      return await scheduler.pendingReminderCountForHabit(habitId);
    } catch (error, stackTrace) {
      debugPrint('Could not read habit reminders for $habitId: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    }
  }

  int completedHabitCountForDate(DateTime date) {
    return habitsForDate(
      date,
    ).where((habit) => isCompletedForDate(habit, date)).length;
  }

  Habit _preserveDefinitionHistory({
    required Habit previous,
    required Habit updated,
    required DateTime changedAt,
  }) {
    final definitionChanged =
        previous.targetValue != updated.targetValue ||
        !_sameWeekdaySet(previous.weekdays, updated.weekdays);

    if (!definitionChanged) {
      return updated.copyWith(
        definitionEffectiveFromDay: previous.definitionEffectiveFromDay,
        definitionHistory: previous.definitionHistory,
      );
    }

    final changedDay = _dateOnly(changedAt);
    final history = List<HabitDefinitionRevision>.from(
      previous.definitionHistory,
    );

    if (previous.definitionEffectiveFromDay.isBefore(changedDay)) {
      history.add(
        HabitDefinitionRevision(
          effectiveFromDay: previous.definitionEffectiveFromDay,
          effectiveUntilDayExclusive: changedDay,
          targetValue: previous.targetValue,
          weekdays: previous.weekdays,
        ),
      );
    }

    return updated.copyWith(
      definitionEffectiveFromDay: changedDay,
      definitionHistory: history,
    );
  }

  bool _sameWeekdaySet(Set<int> first, Set<int> second) {
    if (first.length != second.length) return false;
    return first.every(second.contains);
  }

  Future<void> _scheduleReminderSafely(Habit habit) async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      _lastReminderResult = null;
      return;
    }

    try {
      _lastReminderResult = await scheduler.scheduleForHabit(habit);
    } catch (error, stackTrace) {
      _lastReminderResult = HabitReminderScheduleResult.error(
        habitId: habit.id,
        message: 'Habit reminder scheduling failed: $error',
      );
      debugPrint('Could not schedule habit reminder for ${habit.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _cancelReminderSafely(String habitId) async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) return;

    try {
      await scheduler.cancelForHabit(habitId);
    } catch (error, stackTrace) {
      debugPrint('Could not cancel habit reminder for $habitId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _generateId(DateTime now) {
    return 'habit_${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

import '../models/habit.dart';
import '../models/habit_analytics_summary.dart';
import '../models/habit_progress.dart';
import '../models/habit_period_summary.dart';

class HabitAnalyticsService {
  const HabitAnalyticsService();

  HabitAnalyticsSummary analyze({
    required Habit habit,
    required List<HabitProgress> progress,
    DateTime? asOf,
  }) {
    final today = _dateOnly(asOf ?? DateTime.now());
    final created = _dateOnly(habit.createdAt);
    final progressByDay = <String, HabitProgress>{
      for (final item in progress.where((item) => item.habitId == habit.id))
        _dayKey(item.date): item,
    };

    bool completedOn(DateTime date) {
      final target = habit.targetValueForDate(date);
      if (target == null || !habit.occursOnDate(date) || date.isBefore(created)) {
        return false;
      }
      return (progressByDay[_dayKey(date)]?.value ?? 0) >= target;
    }

    int progressOn(DateTime date) => progressByDay[_dayKey(date)]?.value ?? 0;

    final scheduledLifetime = <DateTime>[];
    if (!created.isAfter(today)) {
      for (var day = created; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
        if (habit.occursOnDate(day)) {
          scheduledLifetime.add(day);
        }
      }
    }

    var currentStreak = 0;
    var currentIndex = scheduledLifetime.length - 1;

    // An unfinished occurrence today is still in progress and does not break
    // a streak before the day has ended.
    if (currentIndex >= 0 &&
        _sameDate(scheduledLifetime[currentIndex], today) &&
        !completedOn(today)) {
      currentIndex--;
    }

    for (var index = currentIndex; index >= 0; index--) {
      if (!completedOn(scheduledLifetime[index])) break;
      currentStreak++;
    }

    var bestStreak = 0;
    var running = 0;
    for (final day in scheduledLifetime) {
      if (_sameDate(day, today) && !completedOn(day)) {
        // Do not count an unfinished current-day occurrence as a failure yet.
        continue;
      }
      if (completedOn(day)) {
        running++;
        if (running > bestStreak) bestStreak = running;
      } else {
        running = 0;
      }
    }

    final weekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final last7Start = today.subtract(const Duration(days: 6));
    final last30Start = today.subtract(const Duration(days: 29));
    final monthStart = DateTime(today.year, today.month, 1);

    final week = _rangeCounts(
      habit: habit,
      start: _laterOf(created, weekStart),
      end: today,
      completedOn: completedOn,
    );
    final last7 = _rangeCounts(
      habit: habit,
      start: _laterOf(created, last7Start),
      end: today,
      completedOn: completedOn,
    );
    final last30 = _rangeCounts(
      habit: habit,
      start: _laterOf(created, last30Start),
      end: today,
      completedOn: completedOn,
    );
    final month = _rangeCounts(
      habit: habit,
      start: _laterOf(created, monthStart),
      end: today,
      completedOn: completedOn,
    );

    final historyStart = _laterOf(created, last30Start);
    final history = <HabitHistoryDay>[];
    if (!historyStart.isAfter(today)) {
      for (var day = historyStart; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
        final scheduled = habit.occursOnDate(day);
        history.add(
          HabitHistoryDay(
            date: day,
            scheduled: scheduled,
            completed: scheduled && completedOn(day),
            progress: progressOn(day),
          ),
        );
      }
    }

    final lifetimeCompleted = scheduledLifetime.where(completedOn).length;

    return HabitAnalyticsSummary(
      habit: habit,
      asOf: today,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      completedThisWeek: week.completed,
      scheduledThisWeek: week.scheduled,
      completedLast7Days: last7.completed,
      scheduledLast7Days: last7.scheduled,
      completedLast30Days: last30.completed,
      scheduledLast30Days: last30.scheduled,
      completedThisMonth: month.completed,
      scheduledThisMonth: month.scheduled,
      lifetimeCompleted: lifetimeCompleted,
      lifetimeScheduled: scheduledLifetime.length,
      historyLast30Days: history,
    );
  }

  HabitPeriodSummary analyzePeriod({
    required List<Habit> habits,
    required List<HabitProgress> progress,
    required DateTime startDay,
    required DateTime endDayExclusive,
    DateTime? asOf,
  }) {
    final start = _dateOnly(startDay);
    final end = _dateOnly(endDayExclusive);
    final currentDay = asOf == null ? null : _dateOnly(asOf);
    final progressByKey = <String, HabitProgress>{
      for (final item in progress)
        '${item.habitId}_${_dayKey(item.date)}': item,
    };

    var scheduled = 0;
    var completed = 0;
    final activeIds = <String>{};

    for (var day = start; day.isBefore(end); day = day.add(const Duration(days: 1))) {
      for (final habit in habits) {
        final created = _dateOnly(habit.createdAt);
        if (day.isBefore(created) || !habit.occursOnDate(day)) continue;
        final target = habit.targetValueForDate(day);
        if (target == null) continue;
        activeIds.add(habit.id);

        // A current calendar day is still open. Weekly/trend consistency
        // should not treat unfinished habits today as historical failures.
        if (currentDay != null && _sameDate(day, currentDay)) {
          continue;
        }

        scheduled++;
        final value = progressByKey['${habit.id}_${_dayKey(day)}']?.value ?? 0;
        if (value >= target) completed++;
      }
    }

    return HabitPeriodSummary(
      startDay: start,
      endDayExclusive: end,
      activeHabitCount: activeIds.length,
      scheduledOccurrences: scheduled,
      completedOccurrences: completed,
    );
  }

  _RangeCounts _rangeCounts({
    required Habit habit,
    required DateTime start,
    required DateTime end,
    required bool Function(DateTime) completedOn,
  }) {
    if (start.isAfter(end)) return const _RangeCounts();

    var scheduled = 0;
    var completed = 0;

    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      if (!habit.occursOnDate(day)) continue;
      scheduled++;
      if (completedOn(day)) completed++;
    }

    return _RangeCounts(scheduled: scheduled, completed: completed);
  }

  DateTime _laterOf(DateTime first, DateTime second) =>
      first.isAfter(second) ? first : second;

  DateTime _dateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  String _dayKey(DateTime date) {
    final day = _dateOnly(date);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _RangeCounts {
  final int scheduled;
  final int completed;

  const _RangeCounts({
    this.scheduled = 0,
    this.completed = 0,
  });
}

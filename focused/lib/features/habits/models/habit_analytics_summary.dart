import 'habit.dart';

class HabitHistoryDay {
  final DateTime date;
  final bool scheduled;
  final bool completed;
  final int progress;

  HabitHistoryDay({
    required DateTime date,
    required this.scheduled,
    required this.completed,
    required this.progress,
  }) : date = DateTime(date.year, date.month, date.day);
}

class HabitAnalyticsSummary {
  final Habit habit;
  final DateTime asOf;
  final int currentStreak;
  final int bestStreak;
  final int completedThisWeek;
  final int scheduledThisWeek;
  final int completedLast7Days;
  final int scheduledLast7Days;
  final int completedLast30Days;
  final int scheduledLast30Days;
  final int completedThisMonth;
  final int scheduledThisMonth;
  final int lifetimeCompleted;
  final int lifetimeScheduled;
  final List<HabitHistoryDay> historyLast30Days;

  HabitAnalyticsSummary({
    required this.habit,
    required DateTime asOf,
    required this.currentStreak,
    required this.bestStreak,
    required this.completedThisWeek,
    required this.scheduledThisWeek,
    required this.completedLast7Days,
    required this.scheduledLast7Days,
    required this.completedLast30Days,
    required this.scheduledLast30Days,
    required this.completedThisMonth,
    required this.scheduledThisMonth,
    required this.lifetimeCompleted,
    required this.lifetimeScheduled,
    required List<HabitHistoryDay> historyLast30Days,
  })  : asOf = DateTime(asOf.year, asOf.month, asOf.day),
        historyLast30Days = List<HabitHistoryDay>.unmodifiable(historyLast30Days);

  double get weeklyCompletionRate =>
      _rate(completedThisWeek, scheduledThisWeek);

  double get last7DaysCompletionRate =>
      _rate(completedLast7Days, scheduledLast7Days);

  double get last30DaysCompletionRate =>
      _rate(completedLast30Days, scheduledLast30Days);

  double get monthCompletionRate =>
      _rate(completedThisMonth, scheduledThisMonth);

  double get lifetimeCompletionRate =>
      _rate(lifetimeCompleted, lifetimeScheduled);

  static double _rate(int completed, int scheduled) {
    if (scheduled <= 0) return 0;
    return (completed / scheduled).clamp(0.0, 1.0).toDouble();
  }
}

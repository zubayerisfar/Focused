class HabitPeriodSummary {
  final DateTime startDay;
  final DateTime endDayExclusive;
  final int activeHabitCount;
  final int scheduledOccurrences;
  final int completedOccurrences;

  HabitPeriodSummary({
    required DateTime startDay,
    required DateTime endDayExclusive,
    required this.activeHabitCount,
    required this.scheduledOccurrences,
    required this.completedOccurrences,
  })  : startDay = DateTime(startDay.year, startDay.month, startDay.day),
        endDayExclusive = DateTime(
          endDayExclusive.year,
          endDayExclusive.month,
          endDayExclusive.day,
        );

  double get completionRate {
    if (scheduledOccurrences <= 0) return 0;
    return (completedOccurrences / scheduledOccurrences)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class ProductivityStreakService {
  const ProductivityStreakService();

  /// Calculates the current local-calendar-day productivity streak.
  ///
  /// A productive day is any date present in [activityDates]. The caller is
  /// responsible for deciding what counts as productive activity. Focused's
  /// dashboard currently uses either a completed task occurrence or positive
  /// active-focus time.
  ///
  /// If today has no activity yet, yesterday is used as the starting point so
  /// the streak does not reset simply because the current day is unfinished.
  int calculateCurrentStreak({
    required DateTime now,
    required Iterable<DateTime> activityDates,
  }) {
    final activeDays = <DateTime>{
      for (final date in activityDates) _dateOnlyLocal(date),
    };

    if (activeDays.isEmpty) {
      return 0;
    }

    var cursor = _dateOnlyLocal(now);

    if (!activeDays.contains(cursor)) {
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day - 1,
      );
    }

    var streak = 0;

    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day - 1,
      );
    }

    return streak;
  }

  /// Calculates the longest productivity streak across all known local dates.
  int calculateLongestStreak({
    required Iterable<DateTime> activityDates,
  }) {
    final days = <DateTime>{
      for (final date in activityDates) _dateOnlyLocal(date),
    }.toList()
      ..sort();

    if (days.isEmpty) return 0;

    var longest = 1;
    var current = 1;

    for (var index = 1; index < days.length; index++) {
      final previous = days[index - 1];
      final expected = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );

      if (days[index] == expected) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }
}


DateTime _dateOnlyLocal(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;

  return DateTime(
    local.year,
    local.month,
    local.day,
  );
}

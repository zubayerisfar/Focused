enum StreakStatus {
  /// User has completed a task today, or completed yesterday and today is still active.
  active,

  /// User missed yesterday, but had a streak before yesterday.
  /// 1-day grace period is active today to restore with ad or gems.
  inDanger,

  /// Missed 2 or more days consecutively (or user has no streak).
  broken,

  /// No streak history.
  none,
}

class StreakDetails {
  final int currentStreak;
  final int longestStreak;
  final StreakStatus status;
  final DateTime? missedDate;
  final bool canRestore;

  const StreakDetails({
    required this.currentStreak,
    required this.longestStreak,
    required this.status,
    this.missedDate,
    required this.canRestore,
  });

  bool get isInDanger => status == StreakStatus.inDanger;
}

class ProductivityStreakService {
  const ProductivityStreakService();

  /// Calculates the current local-calendar-day productivity streak.
  ///
  /// A productive day is any date present in [activityDates] or [restoredDates].
  int calculateCurrentStreak({
    required DateTime now,
    required Iterable<DateTime> activityDates,
    Iterable<DateTime>? restoredDates,
  }) {
    final activeDays = <DateTime>{
      for (final date in activityDates) _dateOnlyLocal(date),
      if (restoredDates != null)
        for (final date in restoredDates) _dateOnlyLocal(date),
    };

    if (activeDays.isEmpty) {
      return 0;
    }

    final today = _dateOnlyLocal(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    var cursor = today;
    if (!activeDays.contains(cursor)) {
      cursor = yesterday;
    }

    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    return streak;
  }

  /// Calculates the longest productivity streak across all known local dates.
  int calculateLongestStreak({
    required Iterable<DateTime> activityDates,
    Iterable<DateTime>? restoredDates,
  }) {
    final days = <DateTime>{
      for (final date in activityDates) _dateOnlyLocal(date),
      if (restoredDates != null)
        for (final date in restoredDates) _dateOnlyLocal(date),
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

  /// Evaluates full streak details including whether the streak is active,
  /// frozen in danger (1-day grace period for yesterday), or broken.
  StreakDetails evaluateStreakDetails({
    required DateTime now,
    required Iterable<DateTime> activityDates,
    Iterable<DateTime>? restoredDates,
    bool debugForceDanger = false,
  }) {
    final activeDays = <DateTime>{
      for (final date in activityDates) _dateOnlyLocal(date),
      if (restoredDates != null)
        for (final date in restoredDates) _dateOnlyLocal(date),
    };

    final longest = calculateLongestStreak(
      activityDates: activityDates,
      restoredDates: restoredDates,
    );

    if (activeDays.isEmpty) {
      if (debugForceDanger) {
        final today = _dateOnlyLocal(now);
        final yesterday = DateTime(today.year, today.month, today.day - 1);
        return StreakDetails(
          currentStreak: 3,
          longestStreak: longest > 3 ? longest : 3,
          status: StreakStatus.inDanger,
          missedDate: yesterday,
          canRestore: true,
        );
      }
      return const StreakDetails(
        currentStreak: 0,
        longestStreak: 0,
        status: StreakStatus.none,
        canRestore: false,
      );
    }

    final today = _dateOnlyLocal(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);

    final currentStreak = calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
      restoredDates: restoredDates,
    );

    // If QA debug flag is forced
    if (debugForceDanger) {
      final effectiveCount = currentStreak > 0 ? currentStreak : 3;
      return StreakDetails(
        currentStreak: effectiveCount,
        longestStreak: longest > effectiveCount ? longest : effectiveCount,
        status: StreakStatus.inDanger,
        missedDate: yesterday,
        canRestore: true,
      );
    }

    // Check today and yesterday activity
    final hasToday = activeDays.contains(today);
    final hasYesterday = activeDays.contains(yesterday);

    if (hasToday || hasYesterday) {
      return StreakDetails(
        currentStreak: currentStreak,
        longestStreak: longest,
        status: currentStreak > 0 ? StreakStatus.active : StreakStatus.none,
        canRestore: false,
      );
    }

    // Yesterday was missed! Did the user have an active streak leading up to 2 days ago?
    if (activeDays.contains(twoDaysAgo)) {
      // Calculate what the streak was ending at two days ago
      var prevStreak = 0;
      var cursor = twoDaysAgo;
      while (activeDays.contains(cursor)) {
        prevStreak++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }

      if (prevStreak > 0) {
        return StreakDetails(
          currentStreak: prevStreak,
          longestStreak: longest,
          status: StreakStatus.inDanger,
          missedDate: yesterday,
          canRestore: true,
        );
      }
    }

    // Both yesterday and the day before (or older) have no activity -> broken streak = 0
    return StreakDetails(
      currentStreak: 0,
      longestStreak: longest,
      status: StreakStatus.broken,
      canRestore: false,
    );
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

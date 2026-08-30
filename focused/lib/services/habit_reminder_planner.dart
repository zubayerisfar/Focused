class HabitReminderPlanner {
  const HabitReminderPlanner();

  DateTime nextForWeekday({
    required DateTime now,
    required int weekday,
    required int minutesFromMidnight,
  }) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday', 'Must be between 1 and 7.');
    }
    if (minutesFromMidnight < 0 || minutesFromMidnight >= 24 * 60) {
      throw ArgumentError.value(
        minutesFromMidnight,
        'minutesFromMidnight',
        'Must be within a single day.',
      );
    }

    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;
    var daysAhead = (weekday - now.weekday) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      hour,
      minute,
    );

    if (!candidate.isAfter(now)) {
      daysAhead += 7;
      candidate = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        hour,
        minute,
      );
    }

    return candidate;
  }

  List<DateTime> planSelectedWeekdays({
    required DateTime now,
    required Set<int> weekdays,
    required int minutesFromMidnight,
  }) {
    final ordered = weekdays.toList()..sort();
    return List<DateTime>.unmodifiable(
      ordered.map(
        (weekday) => nextForWeekday(
          now: now,
          weekday: weekday,
          minutesFromMidnight: minutesFromMidnight,
        ),
      ),
    );
  }
}

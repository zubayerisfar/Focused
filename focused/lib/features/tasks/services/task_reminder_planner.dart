class TaskReminderTimingPlan {
  final bool showNow;
  final DateTime? nextReminderAt;

  const TaskReminderTimingPlan({
    required this.showNow,
    required this.nextReminderAt,
  });
}

class TaskReminderPlanner {
  const TaskReminderPlanner();

  TaskReminderTimingPlan planOneTime({
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    required int reminderMinutesBefore,
    required DateTime now,
  }) {
    final reminderAt = scheduledStart.subtract(
      Duration(minutes: reminderMinutesBefore),
    );

    if (reminderAt.isAfter(now)) {
      return TaskReminderTimingPlan(
        showNow: false,
        nextReminderAt: reminderAt,
      );
    }

    if (now.isBefore(scheduledEnd)) {
      return const TaskReminderTimingPlan(
        showNow: true,
        nextReminderAt: null,
      );
    }

    return const TaskReminderTimingPlan(
      showNow: false,
      nextReminderAt: null,
    );
  }

  TaskReminderTimingPlan planDaily({
    required DateTime anchorStart,
    required DateTime anchorEnd,
    required int reminderMinutesBefore,
    required DateTime now,
  }) {
    final duration = anchorEnd.difference(anchorStart);
    final anchorDay = _dateOnly(anchorStart);
    final nowDay = _dateOnly(now);

    DateTime occurrenceStart;

    if (nowDay.isBefore(anchorDay)) {
      occurrenceStart = anchorStart;
    } else {
      occurrenceStart = _withAnchorTime(
        anchorStart,
        nowDay,
      );
    }

    var showNow = false;

    for (var attempt = 0; attempt < 3; attempt++) {
      final occurrenceEnd = occurrenceStart.add(duration);
      final reminderAt = occurrenceStart.subtract(
        Duration(minutes: reminderMinutesBefore),
      );

      if (reminderAt.isAfter(now)) {
        return TaskReminderTimingPlan(
          showNow: showNow,
          nextReminderAt: reminderAt,
        );
      }

      if (now.isBefore(occurrenceEnd)) {
        showNow = true;
      }

      occurrenceStart = _shiftCalendarDays(
        occurrenceStart,
        1,
      );
    }

    return TaskReminderTimingPlan(
      showNow: showNow,
      nextReminderAt: occurrenceStart.subtract(
        Duration(minutes: reminderMinutesBefore),
      ),
    );
  }

  TaskReminderTimingPlan planWeeklyDay({
    required DateTime anchorStart,
    required DateTime anchorEnd,
    required int occurrenceWeekday,
    required int reminderMinutesBefore,
    required DateTime now,
  }) {
    if (occurrenceWeekday < DateTime.monday ||
        occurrenceWeekday > DateTime.sunday) {
      throw ArgumentError(
        'occurrenceWeekday must be between 1 and 7.',
      );
    }

    final duration = anchorEnd.difference(anchorStart);
    final anchorDay = _dateOnly(anchorStart);
    final nowDay = _dateOnly(now);

    final baseDay = nowDay.isBefore(anchorDay) ? anchorDay : nowDay;
    var occurrenceDay = _nextOrSameWeekday(
      baseDay,
      occurrenceWeekday,
    );

    if (occurrenceDay.isBefore(anchorDay)) {
      occurrenceDay = _shiftCalendarDays(
        occurrenceDay,
        7,
      );
    }

    var occurrenceStart = _withAnchorTime(
      anchorStart,
      occurrenceDay,
    );

    var showNow = false;

    for (var attempt = 0; attempt < 3; attempt++) {
      final occurrenceEnd = occurrenceStart.add(duration);
      final reminderAt = occurrenceStart.subtract(
        Duration(minutes: reminderMinutesBefore),
      );

      if (reminderAt.isAfter(now)) {
        return TaskReminderTimingPlan(
          showNow: showNow,
          nextReminderAt: reminderAt,
        );
      }

      if (now.isBefore(occurrenceEnd)) {
        showNow = true;
      }

      occurrenceStart = _shiftCalendarDays(
        occurrenceStart,
        7,
      );
    }

    return TaskReminderTimingPlan(
      showNow: showNow,
      nextReminderAt: occurrenceStart.subtract(
        Duration(minutes: reminderMinutesBefore),
      ),
    );
  }

  DateTime _withAnchorTime(
    DateTime anchor,
    DateTime day,
  ) {
    return DateTime(
      day.year,
      day.month,
      day.day,
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    );
  }

  DateTime _nextOrSameWeekday(
    DateTime date,
    int weekday,
  ) {
    final daysAhead = (weekday - date.weekday) % 7;

    return DateTime(
      date.year,
      date.month,
      date.day + daysAhead,
    );
  }

  DateTime _shiftCalendarDays(
    DateTime date,
    int days,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day + days,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }
}

import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_recurrence.dart';

class TaskScheduleService {
  const TaskScheduleService();

  bool occursOnDate(
    Task task,
    DateTime date,
  ) {
    final scheduledStart = task.scheduledStart;
    final scheduledEnd = task.scheduledEnd;

    if (scheduledStart == null || scheduledEnd == null) {
      return false;
    }

    final anchorDay = _dateOnly(scheduledStart);
    final targetDay = _dateOnly(date);

    if (targetDay.isBefore(anchorDay)) {
      return false;
    }

    switch (task.recurrence) {
      case TaskRecurrence.none:
        return _sameDate(anchorDay, targetDay);

      case TaskRecurrence.daily:
        return true;

      case TaskRecurrence.weekdays:
        return targetDay.weekday >= DateTime.monday &&
            targetDay.weekday <= DateTime.friday;

      case TaskRecurrence.weekly:
        return targetDay.weekday == anchorDay.weekday;

      case TaskRecurrence.customDays:
        return task.customWeekdays.contains(
          targetDay.weekday,
        );
    }
  }

  TaskOccurrence? occurrenceForDate(
    Task task,
    DateTime date,
  ) {
    if (!occursOnDate(task, date)) {
      return null;
    }

    final originalStart = task.scheduledStart!;
    final originalEnd = task.scheduledEnd!;
    final duration = originalEnd.difference(originalStart);
    final day = _dateOnly(date);

    final start = DateTime(
      day.year,
      day.month,
      day.day,
      originalStart.hour,
      originalStart.minute,
      originalStart.second,
      originalStart.millisecond,
      originalStart.microsecond,
    );

    return TaskOccurrence(
      task: task,
      start: start,
      end: start.add(duration),
    );
  }

  DateTime? nextOccurrenceStart(
    Task task,
    DateTime after, {
    int searchDays = 370,
  }) {
    if (task.scheduledStart == null ||
        task.scheduledEnd == null) {
      return null;
    }

    for (var offset = 0; offset <= searchDays; offset++) {
      final day = DateTime(
        after.year,
        after.month,
        after.day + offset,
      );

      final occurrence = occurrenceForDate(
        task,
        day,
      );

      if (occurrence == null) {
        continue;
      }

      if (occurrence.start.isAfter(after)) {
        return occurrence.start;
      }
    }

    return null;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _sameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

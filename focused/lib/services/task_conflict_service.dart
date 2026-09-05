import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../models/task_schedule_conflict.dart';
import 'task_schedule_service.dart';

class TaskConflictService {
  final TaskScheduleService _scheduleService;

  const TaskConflictService({
    TaskScheduleService scheduleService = const TaskScheduleService(),
  }) : _scheduleService = scheduleService;

  List<TaskScheduleConflict> findConflicts({
    required DateTime candidateStart,
    required DateTime candidateEnd,
    required TaskRecurrence recurrence,
    required Set<int> customWeekdays,
    required List<Task> existingTasks,
    String? ignoreTaskId,
  }) {
    if (!candidateEnd.isAfter(candidateStart)) {
      throw ArgumentError('Candidate end must be after candidate start.');
    }

    if (recurrence == TaskRecurrence.customDays && customWeekdays.isEmpty) {
      throw ArgumentError('Custom recurrence requires at least one weekday.');
    }

    final candidate = Task(
      id: '__candidate__',
      title: 'Candidate',
      priority: TaskPriority.important,
      scheduledStart: candidateStart,
      scheduledEnd: candidateEnd,
      recurrence: recurrence,
      customWeekdays: Set<int>.from(customWeekdays),
      createdAt: candidateStart,
    );

    final conflicts = <TaskScheduleConflict>[];

    for (final existing in existingTasks) {
      if (existing.id == ignoreTaskId ||
          existing.isReminder ||
          existing.isCompleted ||
          existing.scheduledStart == null ||
          existing.scheduledEnd == null) {
        continue;
      }

      final conflict = _firstConflict(candidate, existing);
      if (conflict != null) {
        conflicts.add(conflict);
      }
    }

    conflicts.sort(
      (first, second) => first.candidateStart.compareTo(second.candidateStart),
    );

    return List.unmodifiable(conflicts);
  }

  TaskScheduleConflict? _firstConflict(Task candidate, Task existing) {
    final candidateRecurring = candidate.recurrence != TaskRecurrence.none;
    final existingRecurring = existing.recurrence != TaskRecurrence.none;

    if (!candidateRecurring && !existingRecurring) {
      return _buildIfOverlapping(
        candidate,
        existing,
        candidate.scheduledStart!,
        candidate.scheduledEnd!,
        existing.scheduledStart!,
        existing.scheduledEnd!,
      );
    }

    if (!candidateRecurring) {
      return _conflictAgainstRecurring(
        oneTime: candidate,
        recurring: existing,
        candidateIsOneTime: true,
      );
    }

    if (!existingRecurring) {
      return _conflictAgainstRecurring(
        oneTime: existing,
        recurring: candidate,
        candidateIsOneTime: false,
      );
    }

    // Every supported recurrence pattern repeats on a seven-day cycle.
    // Starting from the later anchor and checking two full weeks safely
    // covers weekday/custom-day alignment and anchor-boundary cases.
    final candidateAnchor = _dateOnly(candidate.scheduledStart!);
    final existingAnchor = _dateOnly(existing.scheduledStart!);
    final searchStart = candidateAnchor.isAfter(existingAnchor)
        ? candidateAnchor
        : existingAnchor;

    for (var offset = -1; offset <= 14; offset++) {
      final day = DateTime(
        searchStart.year,
        searchStart.month,
        searchStart.day + offset,
      );

      final candidateOccurrence = _scheduleService.occurrenceForDate(
        candidate,
        day,
      );

      if (candidateOccurrence == null) {
        continue;
      }

      // Check surrounding start-days too. This catches both tasks that
      // cross midnight and unusually long scheduled blocks.
      for (final existingDayOffset in _relevantDayOffsets(
        candidate.scheduledEnd!.difference(candidate.scheduledStart!),
        existing.scheduledEnd!.difference(existing.scheduledStart!),
      )) {
        final existingDay = DateTime(
          day.year,
          day.month,
          day.day + existingDayOffset,
        );

        final existingOccurrence = _scheduleService.occurrenceForDate(
          existing,
          existingDay,
        );

        if (existingOccurrence == null) {
          continue;
        }

        final result = _buildIfOverlapping(
          candidate,
          existing,
          candidateOccurrence.start,
          candidateOccurrence.end,
          existingOccurrence.start,
          existingOccurrence.end,
        );

        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  TaskScheduleConflict? _conflictAgainstRecurring({
    required Task oneTime,
    required Task recurring,
    required bool candidateIsOneTime,
  }) {
    final oneTimeStart = oneTime.scheduledStart!;
    final oneTimeEnd = oneTime.scheduledEnd!;
    final day = _dateOnly(oneTimeStart);

    for (final offset in _relevantDayOffsets(
      oneTimeEnd.difference(oneTimeStart),
      recurring.scheduledEnd!.difference(recurring.scheduledStart!),
    )) {
      final recurringDay = DateTime(day.year, day.month, day.day + offset);

      final recurringOccurrence = _scheduleService.occurrenceForDate(
        recurring,
        recurringDay,
      );

      if (recurringOccurrence == null) {
        continue;
      }

      if (candidateIsOneTime) {
        final result = _buildIfOverlapping(
          oneTime,
          recurring,
          oneTimeStart,
          oneTimeEnd,
          recurringOccurrence.start,
          recurringOccurrence.end,
        );

        if (result != null) {
          return result;
        }
      } else {
        final result = _buildIfOverlapping(
          recurring,
          oneTime,
          recurringOccurrence.start,
          recurringOccurrence.end,
          oneTimeStart,
          oneTimeEnd,
        );

        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  TaskScheduleConflict? _buildIfOverlapping(
    Task candidate,
    Task existing,
    DateTime candidateStart,
    DateTime candidateEnd,
    DateTime existingStart,
    DateTime existingEnd,
  ) {
    final overlaps =
        candidateStart.isBefore(existingEnd) &&
        candidateEnd.isAfter(existingStart);

    if (!overlaps) {
      return null;
    }

    return TaskScheduleConflict(
      task: existing,
      existingStart: existingStart,
      existingEnd: existingEnd,
      candidateStart: candidateStart,
      candidateEnd: candidateEnd,
    );
  }

  Iterable<int> _relevantDayOffsets(
    Duration candidateDuration,
    Duration existingDuration,
  ) sync* {
    final existingLookback = _coveredDayCount(existingDuration);
    final candidateLookahead = _coveredDayCount(candidateDuration);

    for (
      var offset = -existingLookback;
      offset <= candidateLookahead;
      offset++
    ) {
      yield offset;
    }
  }

  int _coveredDayCount(Duration duration) {
    final microsPerDay = const Duration(days: 1).inMicroseconds;
    final micros = duration.inMicroseconds;

    if (micros <= 0) {
      return 0;
    }

    return (micros / microsPerDay).ceil();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

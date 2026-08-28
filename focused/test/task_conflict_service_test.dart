import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/services/task_conflict_service.dart';

void main() {
  const service = TaskConflictService();

  Task task({
    required String id,
    required DateTime start,
    required DateTime end,
    TaskRecurrence recurrence = TaskRecurrence.none,
    Set<int> customWeekdays = const {},
    bool completed = false,
  }) {
    var result = Task(
      id: id,
      title: id,
      priority: TaskPriority.important,
      scheduledStart: start,
      scheduledEnd: end,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      createdAt: DateTime(2026, 8, 1),
    );

    if (completed) {
      result = result.markCompleted(DateTime(2026, 8, 1, 12));
    }

    return result;
  }

  test('overlapping one-time tasks conflict', () {
    final existing = task(
      id: 'code',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 27, 20),
      candidateEnd: DateTime(2026, 8, 27, 22),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
    );

    expect(conflicts, hasLength(1));
  });

  test('touching blocks are not conflicts', () {
    final existing = task(
      id: 'code',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 27, 20),
      candidateEnd: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
    );

    expect(conflicts, isEmpty);
  });

  test('same clock time on different one-time dates does not conflict', () {
    final existing = task(
      id: 'code',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 28, 19),
      candidateEnd: DateTime(2026, 8, 28, 21),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
    );

    expect(conflicts, isEmpty);
  });

  test('editing task ignores itself', () {
    final existing = task(
      id: 'code',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 27, 19, 30),
      candidateEnd: DateTime(2026, 8, 27, 21, 30),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
      ignoreTaskId: 'code',
    );

    expect(conflicts, isEmpty);
  });

  test('daily recurrence conflicts with later one-time occurrence', () {
    final daily = task(
      id: 'daily',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.daily,
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 30, 20),
      candidateEnd: DateTime(2026, 8, 30, 21, 30),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [daily],
    );

    expect(conflicts, hasLength(1));
  });

  test('weekly recurrences on different weekdays do not conflict', () {
    final thursday = task(
      id: 'thursday',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.weekly,
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 28, 19, 30),
      candidateEnd: DateTime(2026, 8, 28, 20, 30),
      recurrence: TaskRecurrence.weekly,
      customWeekdays: const {},
      existingTasks: [thursday],
    );

    expect(conflicts, isEmpty);
  });

  test('weekly same weekday overlapping time conflicts', () {
    final thursday = task(
      id: 'thursday',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.weekly,
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 9, 3, 20),
      candidateEnd: DateTime(2026, 9, 3, 22),
      recurrence: TaskRecurrence.weekly,
      customWeekdays: const {},
      existingTasks: [thursday],
    );

    expect(conflicts, hasLength(1));
  });

  test('custom weekdays conflict only on selected days', () {
    final existing = task(
      id: 'm-w-f',
      start: DateTime(2026, 8, 28, 19),
      end: DateTime(2026, 8, 28, 21),
      recurrence: TaskRecurrence.customDays,
      customWeekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
    );

    final tuesday = service.findConflicts(
      candidateStart: DateTime(2026, 9, 1, 20),
      candidateEnd: DateTime(2026, 9, 1, 21),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
    );

    final wednesday = service.findConflicts(
      candidateStart: DateTime(2026, 9, 2, 20),
      candidateEnd: DateTime(2026, 9, 2, 21),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [existing],
    );

    expect(tuesday, isEmpty);
    expect(wednesday, hasLength(1));
  });

  test('completed tasks do not block schedule', () {
    final completed = task(
      id: 'done',
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
      completed: true,
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 27, 20),
      candidateEnd: DateTime(2026, 8, 27, 22),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [completed],
    );

    expect(conflicts, isEmpty);
  });

  test('cross-midnight recurring occurrence conflicts next day', () {
    final overnight = task(
      id: 'overnight',
      start: DateTime(2026, 8, 27, 23),
      end: DateTime(2026, 8, 28, 1),
      recurrence: TaskRecurrence.daily,
    );

    final conflicts = service.findConflicts(
      candidateStart: DateTime(2026, 8, 28, 0, 30),
      candidateEnd: DateTime(2026, 8, 28, 1, 30),
      recurrence: TaskRecurrence.none,
      customWeekdays: const {},
      existingTasks: [overnight],
    );

    expect(conflicts, hasLength(1));
  });
}

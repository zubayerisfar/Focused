import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/providers/task_provider.dart';

void main() {
  test('createTask uses current model without estimated duration', () async {
    final provider = TaskProvider();

    final task = await provider.createTask(
      title: 'Code',
      priority: TaskPriority.important,
      plannedDate: DateTime(2026, 8, 27),
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 21),
      createdAt: DateTime(2026, 8, 27, 12),
    );

    expect(provider.tasks, hasLength(1));
    expect(task.scheduledDurationMinutes, 120);
  });

  test('provider exposes recurrence-aware conflict checking', () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'daily',
        title: 'Daily Code',
        priority: TaskPriority.important,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 21),
        recurrence: TaskRecurrence.daily,
        createdAt: DateTime(2026, 8, 27),
      ),
    );

    final conflicts = provider.findScheduleConflicts(
      scheduledStart: DateTime(2026, 8, 30, 20),
      scheduledEnd: DateTime(2026, 8, 30, 21),
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single.task.id, 'daily');
  });

  test('provider ignores edited task ID during conflict check', () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'same',
        title: 'Same task',
        priority: TaskPriority.important,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 20),
        createdAt: DateTime(2026, 8, 27),
      ),
    );

    final conflicts = provider.findScheduleConflicts(
      scheduledStart: DateTime(2026, 8, 27, 19, 15),
      scheduledEnd: DateTime(2026, 8, 27, 20, 15),
      ignoreTaskId: 'same',
    );

    expect(conflicts, isEmpty);
  });

  test('completing and reopening one recurring occurrence preserves series metadata',
      () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'repeat',
        title: 'Repeat',
        priority: TaskPriority.growth,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 20),
        recurrence: TaskRecurrence.customDays,
        customWeekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
        reminderMinutesBefore: 15,
        createdAt: DateTime(2026, 8, 27),
      ),
    );

    // 2026-08-28 is Friday, so this recurring task has an occurrence.
    final occurrenceDate = DateTime(2026, 8, 28);

    await provider.setCompletedForDate(
      'repeat',
      occurrenceDate,
      true,
      completedAt: DateTime(2026, 8, 28, 20),
    );

    expect(
      provider.isOccurrenceCompleted('repeat', occurrenceDate),
      isTrue,
    );

    await provider.setCompletedForDate(
      'repeat',
      occurrenceDate,
      false,
    );

    expect(
      provider.isOccurrenceCompleted('repeat', occurrenceDate),
      isFalse,
    );

    final task = provider.getTaskById('repeat')!;

    // Completing an occurrence must never complete or mutate the master series.
    expect(task.isCompleted, isFalse);
    expect(task.recurrence, TaskRecurrence.customDays);
    expect(task.reminderMinutesBefore, 15);
    expect(task.scheduledDurationMinutes, 60);
    expect(
      task.customWeekdays,
      const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
    );
  });

  test('nextTask prefers active scheduled occurrence', () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'later',
        title: 'Later',
        priority: TaskPriority.critical,
        plannedDate: DateTime(2026, 8, 27),
        createdAt: DateTime(2026, 8, 27, 8),
      ),
    );

    await provider.addTask(
      Task(
        id: 'active',
        title: 'Active',
        priority: TaskPriority.growth,
        scheduledStart: DateTime(2026, 8, 27, 10),
        scheduledEnd: DateTime(2026, 8, 27, 11),
        createdAt: DateTime(2026, 8, 27, 8),
      ),
    );

    expect(
      provider.nextTask(now: DateTime(2026, 8, 27, 10, 30))!.id,
      'active',
    );
  });
}

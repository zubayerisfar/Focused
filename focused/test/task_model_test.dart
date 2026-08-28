import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';

void main() {
  Task makeTask({
    DateTime? start,
    DateTime? end,
    TaskRecurrence recurrence = TaskRecurrence.none,
    Set<int> customWeekdays = const {},
    int? reminderMinutesBefore,
  }) {
    return Task(
      id: 'task-1',
      title: 'Code',
      priority: TaskPriority.important,
      scheduledStart: start,
      scheduledEnd: end,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      reminderMinutesBefore: reminderMinutesBefore,
      createdAt: DateTime(2026, 8, 27, 12),
    );
  }

  test('scheduled duration is derived only from start and end', () {
    final task = makeTask(
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
    );

    expect(task.scheduledDuration, const Duration(hours: 2));
    expect(task.scheduledDurationMinutes, 120);
    expect(task.defaultFocusMinutes, 120);
  });

  test('unscheduled task has flexible duration and defaults focus to 60', () {
    final task = makeTask();

    expect(task.scheduledDuration, isNull);
    expect(task.scheduledDurationMinutes, isNull);
    expect(task.defaultFocusMinutes, 60);
  });

  test('scheduled start and end must exist together', () {
    expect(
      () => makeTask(
        start: DateTime(2026, 8, 27, 19),
      ),
      throwsArgumentError,
    );
  });

  test('scheduled end must be after start', () {
    expect(
      () => makeTask(
        start: DateTime(2026, 8, 27, 20),
        end: DateTime(2026, 8, 27, 19),
      ),
      throwsArgumentError,
    );
  });

  test('recurring task requires schedule', () {
    expect(
      () => makeTask(
        recurrence: TaskRecurrence.daily,
      ),
      throwsArgumentError,
    );
  });

  test('custom recurrence requires at least one weekday', () {
    expect(
      () => makeTask(
        start: DateTime(2026, 8, 27, 19),
        end: DateTime(2026, 8, 27, 20),
        recurrence: TaskRecurrence.customDays,
      ),
      throwsArgumentError,
    );
  });

  test('reminder requires scheduled task', () {
    expect(
      () => makeTask(
        reminderMinutesBefore: 15,
      ),
      throwsArgumentError,
    );
  });

  test('current serialization round-trips schedule and recurrence', () {
    final task = makeTask(
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.customDays,
      customWeekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
      reminderMinutesBefore: 15,
    );

    final map = task.toMap();

    expect(map['schemaVersion'], 3);

    final restored = Task.fromMap(map);
    expect(restored.title, 'Code');
    expect(restored.scheduledDurationMinutes, 120);
    expect(restored.recurrence, TaskRecurrence.customDays);
    expect(
      restored.customWeekdays,
      const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
    );
    expect(restored.reminderMinutesBefore, 15);
  });
}

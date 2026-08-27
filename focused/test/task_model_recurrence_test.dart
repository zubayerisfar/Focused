import 'package:flutter_test/flutter_test.dart';

import '../lib/models/task.dart';
import '../lib/models/task_recurrence.dart';

void main() {
  group('Task recurrence model', () {
    test('serialization preserves recurrence and reminder fields', () {
      final task = Task(
        id: 'daily-code',
        title: 'Code',
        priority: TaskPriority.important,
        estimatedMinutes: 120,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 21),
        recurrence: TaskRecurrence.customDays,
        customWeekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
        reminderMinutesBefore: 15,
        createdAt: DateTime(2026, 8, 27, 10),
      );

      final restored = Task.fromMap(task.toMap());

      expect(restored.id, task.id);
      expect(restored.title, 'Code');
      expect(restored.recurrence, TaskRecurrence.customDays);
      expect(
        restored.customWeekdays,
        {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
      );
      expect(restored.reminderMinutesBefore, 15);
      expect(restored.scheduledStart, task.scheduledStart);
      expect(restored.scheduledEnd, task.scheduledEnd);
    });

    test('markCompleted preserves recurrence metadata', () {
      final task = Task(
        id: 'daily-code',
        title: 'Code',
        priority: TaskPriority.important,
        estimatedMinutes: 120,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 21),
        recurrence: TaskRecurrence.daily,
        reminderMinutesBefore: 15,
        createdAt: DateTime(2026, 8, 27, 10),
      );

      final completed = task.markCompleted(
        DateTime(2026, 8, 27, 21),
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.recurrence, TaskRecurrence.daily);
      expect(completed.reminderMinutesBefore, 15);
      expect(completed.scheduledStart, task.scheduledStart);
      expect(completed.scheduledEnd, task.scheduledEnd);
    });

    test('markIncomplete preserves recurrence metadata', () {
      final completed = Task(
        id: 'weekly-review',
        title: 'Weekly review',
        priority: TaskPriority.growth,
        estimatedMinutes: 60,
        scheduledStart: DateTime(2026, 8, 30, 20),
        scheduledEnd: DateTime(2026, 8, 30, 21),
        recurrence: TaskRecurrence.weekly,
        reminderMinutesBefore: 30,
        isCompleted: true,
        createdAt: DateTime(2026, 8, 27, 10),
        completedAt: DateTime(2026, 8, 30, 21),
      );

      final reopened = completed.markIncomplete();

      expect(reopened.isCompleted, isFalse);
      expect(reopened.completedAt, isNull);
      expect(reopened.recurrence, TaskRecurrence.weekly);
      expect(reopened.reminderMinutesBefore, 30);
    });

    test('recurring task requires schedule', () {
      expect(
        () => Task(
          id: 'bad',
          title: 'Bad recurring task',
          priority: TaskPriority.important,
          estimatedMinutes: 30,
          recurrence: TaskRecurrence.daily,
          createdAt: DateTime(2026, 8, 27),
        ),
        throwsArgumentError,
      );
    });

    test('custom recurrence requires at least one weekday', () {
      expect(
        () => Task(
          id: 'bad-custom',
          title: 'Bad custom task',
          priority: TaskPriority.important,
          estimatedMinutes: 30,
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 20),
          recurrence: TaskRecurrence.customDays,
          createdAt: DateTime(2026, 8, 27),
        ),
        throwsArgumentError,
      );
    });

    test('reminder requires schedule', () {
      expect(
        () => Task(
          id: 'bad-reminder',
          title: 'Bad reminder',
          priority: TaskPriority.important,
          estimatedMinutes: 30,
          reminderMinutesBefore: 15,
          createdAt: DateTime(2026, 8, 27),
        ),
        throwsArgumentError,
      );
    });
  });
}

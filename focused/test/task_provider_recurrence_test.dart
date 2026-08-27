import 'package:flutter_test/flutter_test.dart';

import '../lib/models/task.dart';
import '../lib/models/task_recurrence.dart';
import '../lib/providers/task_provider.dart';

void main() {
  group('TaskProvider recurrence integration', () {
    late TaskProvider provider;

    setUp(() {
      provider = TaskProvider();
    });

    test('createTask actually adds the task to provider memory', () async {
      final created = await provider.createTask(
        title: 'Code',
        priority: TaskPriority.important,
        estimatedMinutes: 120,
        createdAt: DateTime(2026, 8, 27, 10),
      );

      expect(provider.tasks.length, 1);
      expect(provider.tasks.single.id, created.id);
      expect(provider.getTaskById(created.id), isNotNull);
    });

    test('daily recurring task generates a future calendar occurrence', () async {
      await provider.addTask(
        Task(
          id: 'daily-code',
          title: 'Code',
          priority: TaskPriority.important,
          estimatedMinutes: 120,
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 21),
          recurrence: TaskRecurrence.daily,
          reminderMinutesBefore: 15,
          createdAt: DateTime(2026, 8, 27, 10),
        ),
      );

      final occurrences = provider.scheduledOccurrencesForDate(
        DateTime(2026, 9, 2),
      );

      expect(occurrences.length, 1);
      expect(occurrences.single.start, DateTime(2026, 9, 2, 19));
      expect(occurrences.single.end, DateTime(2026, 9, 2, 21));
    });

    test('completed recurring task is excluded when includeCompleted is false', () async {
      await provider.addTask(
        Task(
          id: 'daily-code',
          title: 'Code',
          priority: TaskPriority.important,
          estimatedMinutes: 120,
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 21),
          recurrence: TaskRecurrence.daily,
          createdAt: DateTime(2026, 8, 27, 10),
        ),
      );

      await provider.setCompleted(
        'daily-code',
        true,
        time: DateTime(2026, 8, 27, 21),
      );

      final todayTasks = provider.tasksForDate(
        DateTime(2026, 8, 28),
        includeCompleted: false,
      );

      expect(todayTasks, isEmpty);
      expect(
        provider.scheduledOccurrencesForDate(DateTime(2026, 8, 28)),
        isEmpty,
      );
      expect(
        provider.plannerToday(now: DateTime(2026, 8, 28, 12)),
        isEmpty,
      );
    });

    test('reopening recurring task restores future occurrences', () async {
      await provider.addTask(
        Task(
          id: 'daily-code',
          title: 'Code',
          priority: TaskPriority.important,
          estimatedMinutes: 120,
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 21),
          recurrence: TaskRecurrence.daily,
          reminderMinutesBefore: 15,
          createdAt: DateTime(2026, 8, 27, 10),
        ),
      );

      await provider.setCompleted(
        'daily-code',
        true,
        time: DateTime(2026, 8, 27, 21),
      );
      await provider.setCompleted('daily-code', false);

      final task = provider.getTaskById('daily-code')!;

      expect(task.recurrence, TaskRecurrence.daily);
      expect(task.reminderMinutesBefore, 15);
      expect(
        provider.scheduledOccurrencesForDate(DateTime(2026, 8, 30)).length,
        1,
      );
    });

    test('nextTask uses real recurring occurrence time for today', () async {
      await provider.addTask(
        Task(
          id: 'daily-code',
          title: 'Code',
          priority: TaskPriority.important,
          estimatedMinutes: 120,
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 21),
          recurrence: TaskRecurrence.daily,
          createdAt: DateTime(2026, 8, 27, 10),
        ),
      );

      final next = provider.nextTask(
        now: DateTime(2026, 8, 30, 18),
      );

      expect(next?.id, 'daily-code');
    });

    test('recurring master task is not treated as overdue after anchor day', () async {
      await provider.addTask(
        Task(
          id: 'daily-code',
          title: 'Code',
          priority: TaskPriority.important,
          estimatedMinutes: 120,
          plannedDate: DateTime(2026, 8, 27),
          scheduledStart: DateTime(2026, 8, 27, 19),
          scheduledEnd: DateTime(2026, 8, 27, 21),
          recurrence: TaskRecurrence.daily,
          createdAt: DateTime(2026, 8, 27, 10),
        ),
      );

      final today = provider.plannerToday(
        now: DateTime(2026, 8, 30, 12),
      );

      expect(today.length, 1);
      expect(today.single.id, 'daily-code');
    });
  });
}

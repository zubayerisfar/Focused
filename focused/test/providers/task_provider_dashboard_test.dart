import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/providers/task_provider.dart';

void main() {
  test('today counts include recurring occurrence completion', () async {
    final provider = TaskProvider();
    final today = DateTime(2026, 8, 28);

    await provider.addTask(
      Task(
        id: 'one-time',
        title: 'One time',
        priority: TaskPriority.important,
        plannedDate: today,
        createdAt: DateTime(2026, 8, 28, 8),
      ),
    );

    await provider.addTask(
      Task(
        id: 'daily',
        title: 'Daily',
        priority: TaskPriority.growth,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 20),
        recurrence: TaskRecurrence.daily,
        createdAt: DateTime(2026, 8, 27, 8),
      ),
    );

    await provider.setCompletedForDate(
      'daily',
      today,
      true,
      completedAt: DateTime(2026, 8, 28, 20),
    );

    expect(provider.taskCountForDate(today), 2);
    expect(provider.completedTaskCountForDate(today), 1);
    expect(provider.remainingTaskCountForDate(today), 1);
  });

  test('one-time completion counts for its planned day', () async {
    final provider = TaskProvider();
    final today = DateTime(2026, 8, 28);

    await provider.addTask(
      Task(
        id: 'task',
        title: 'Task',
        priority: TaskPriority.critical,
        plannedDate: today,
        createdAt: DateTime(2026, 8, 28, 8),
      ),
    );

    await provider.setCompleted(
      'task',
      true,
      time: DateTime(2026, 8, 28, 12),
    );

    expect(provider.taskCountForDate(today), 1);
    expect(provider.completedTaskCountForDate(today), 1);
    expect(provider.remainingTaskCountForDate(today), 0);
  });

  test('completion activity uses actual completion date', () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'late',
        title: 'Late task',
        priority: TaskPriority.important,
        plannedDate: DateTime(2026, 8, 27),
        createdAt: DateTime(2026, 8, 27, 8),
      ),
    );

    await provider.setCompleted(
      'late',
      true,
      time: DateTime(2026, 8, 28, 0, 15),
    );

    expect(
      provider.completionActivityDates(),
      contains(DateTime(2026, 8, 28)),
    );
    expect(
      provider.completionActivityDates(),
      isNot(contains(DateTime(2026, 8, 27))),
    );
  });

  test('recurring completion activity uses completedAt date', () async {
    final provider = TaskProvider();

    await provider.addTask(
      Task(
        id: 'daily',
        title: 'Daily',
        priority: TaskPriority.important,
        scheduledStart: DateTime(2026, 8, 27, 19),
        scheduledEnd: DateTime(2026, 8, 27, 20),
        recurrence: TaskRecurrence.daily,
        createdAt: DateTime(2026, 8, 27, 8),
      ),
    );

    await provider.setCompletedForDate(
      'daily',
      DateTime(2026, 8, 27),
      true,
      completedAt: DateTime(2026, 8, 28, 0, 5),
    );

    expect(
      provider.completionActivityDates(),
      contains(DateTime(2026, 8, 28)),
    );
  });
}

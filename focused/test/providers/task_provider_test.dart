import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/task.dart';
import 'package:focused/providers/task_provider.dart';

void main() {
  late TaskProvider provider;

  setUp(() {
    provider = TaskProvider();
  });

  DateTime time(int day, int hour, [int minute = 0]) {
    return DateTime(2026, 8, day, hour, minute);
  }

  Task task({
    required String id,
    required String title,
    TaskPriority priority = TaskPriority.important,
    int estimatedMinutes = 60,
    DateTime? plannedDate,
    DateTime? deadline,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool completed = false,
  }) {
    return Task(
      id: id,
      title: title,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      isCompleted: completed,
      createdAt: time(27, 8),
      completedAt: completed ? time(27, 9) : null,
    );
  }

  test('task rejects an empty title', () {
    expect(() => task(id: '1', title: '   '), throwsArgumentError);
  });

  test('task rejects zero estimated duration', () {
    expect(
      () => task(id: '1', title: 'Study', estimatedMinutes: 0),
      throwsArgumentError,
    );
  });

  test('task rejects invalid scheduled time', () {
    expect(
      () => task(
        id: '1',
        title: 'Study',
        scheduledStart: time(27, 11),
        scheduledEnd: time(27, 10),
      ),
      throwsArgumentError,
    );
  });

  test('duplicate task IDs are rejected', () {
    provider.addTask(task(id: 'same-id', title: 'Task one'));

    expect(
      () => provider.addTask(task(id: 'same-id', title: 'Task two')),
      throwsStateError,
    );
  });

  test('task can be completed and reopened', () {
    provider.addTask(task(id: '1', title: 'Study Flutter'));

    provider.setCompleted('1', true, time: time(27, 12));

    final completed = provider.getTaskById('1')!;

    expect(completed.isCompleted, isTrue);

    expect(completed.completedAt, time(27, 12));

    provider.setCompleted('1', false);

    final reopened = provider.getTaskById('1')!;

    expect(reopened.isCompleted, isFalse);

    expect(reopened.completedAt, isNull);
  });

  test(
    'tasksForDate returns only tasks planned or scheduled for that date',
    () {
      provider.addTask(
        task(id: '1', title: 'Today planned', plannedDate: time(27, 0)),
      );

      provider.addTask(
        task(
          id: '2',
          title: 'Today scheduled',
          scheduledStart: time(27, 15),
          scheduledEnd: time(27, 16),
        ),
      );

      provider.addTask(
        task(id: '3', title: 'Tomorrow', plannedDate: time(28, 0)),
      );

      final result = provider.tasksForDate(time(27, 20));

      expect(result.length, 2);

      expect(result.map((task) => task.id), containsAll(['1', '2']));
    },
  );

  test('priority grouping separates critical important and growth tasks', () {
    provider.addTask(
      task(
        id: '1',
        title: 'Critical',
        priority: TaskPriority.critical,
        plannedDate: time(27, 0),
      ),
    );

    provider.addTask(
      task(
        id: '2',
        title: 'Important',
        priority: TaskPriority.important,
        plannedDate: time(27, 0),
      ),
    );

    provider.addTask(
      task(
        id: '3',
        title: 'Growth',
        priority: TaskPriority.growth,
        plannedDate: time(27, 0),
      ),
    );

    final groups = provider.tasksByPriorityForDate(time(27, 12));

    expect(groups[TaskPriority.critical]!.length, 1);

    expect(groups[TaskPriority.important]!.length, 1);

    expect(groups[TaskPriority.growth]!.length, 1);
  });

  test('active scheduled task becomes next task', () {
    provider.addTask(
      task(
        id: 'normal',
        title: 'Normal task',
        priority: TaskPriority.critical,
        plannedDate: time(27, 0),
      ),
    );

    provider.addTask(
      task(
        id: 'active',
        title: 'Active meeting',
        priority: TaskPriority.important,
        scheduledStart: time(27, 10),
        scheduledEnd: time(27, 11),
      ),
    );

    final next = provider.nextTask(now: time(27, 10, 30));

    expect(next?.id, 'active');
  });

  test('earliest upcoming scheduled task is selected', () {
    provider.addTask(
      task(
        id: 'later',
        title: 'Later',
        scheduledStart: time(27, 16),
        scheduledEnd: time(27, 17),
      ),
    );

    provider.addTask(
      task(
        id: 'earlier',
        title: 'Earlier',
        scheduledStart: time(27, 14),
        scheduledEnd: time(27, 15),
      ),
    );

    final next = provider.nextTask(now: time(27, 12));

    expect(next?.id, 'earlier');
  });

  test('completed tasks are ignored when choosing next task', () {
    provider.addTask(
      task(
        id: 'completed',
        title: 'Finished critical task',
        priority: TaskPriority.critical,
        plannedDate: time(27, 0),
        completed: true,
      ),
    );

    provider.addTask(
      task(
        id: 'open',
        title: 'Open important task',
        priority: TaskPriority.important,
        plannedDate: time(27, 0),
      ),
    );

    final next = provider.nextTask(now: time(27, 12));

    expect(next?.id, 'open');
  });
}

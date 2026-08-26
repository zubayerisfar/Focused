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
  }) {
    return Task(
      id: id,
      title: title,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      createdAt: time(27, 8),
    );
  }

  test('addTask adds task asynchronously', () async {
    await provider.addTask(task(id: '1', title: 'Study Flutter'));

    expect(provider.tasks.length, 1);

    expect(provider.tasks.first.title, 'Study Flutter');
  });

  test('duplicate IDs throw asynchronously', () async {
    await provider.addTask(task(id: 'same-id', title: 'Task one'));

    await expectLater(
      provider.addTask(task(id: 'same-id', title: 'Task two')),
      throwsStateError,
    );
  });

  test('setCompleted completes task', () async {
    await provider.addTask(task(id: '1', title: 'Study Flutter'));

    await provider.setCompleted('1', true, time: time(27, 12));

    final updated = provider.getTaskById('1')!;

    expect(updated.isCompleted, isTrue);

    expect(updated.completedAt, time(27, 12));
  });

  test('setCompleted can reopen task', () async {
    await provider.addTask(task(id: '1', title: 'Study Flutter'));

    await provider.setCompleted('1', true, time: time(27, 12));

    await provider.setCompleted('1', false);

    final updated = provider.getTaskById('1')!;

    expect(updated.isCompleted, isFalse);

    expect(updated.completedAt, isNull);
  });

  test('deleteTask removes task', () async {
    await provider.addTask(task(id: '1', title: 'Delete me'));

    await provider.deleteTask('1');

    expect(provider.getTaskById('1'), isNull);
  });

  test('updateTask replaces existing task', () async {
    await provider.addTask(task(id: '1', title: 'Old title'));

    final updatedTask = Task(
      id: '1',
      title: 'New title',
      priority: TaskPriority.critical,
      estimatedMinutes: 90,
      createdAt: time(27, 8),
    );

    await provider.updateTask(updatedTask);

    final result = provider.getTaskById('1')!;

    expect(result.title, 'New title');

    expect(result.priority, TaskPriority.critical);
  });
}

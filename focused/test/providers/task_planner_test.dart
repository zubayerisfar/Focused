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

  Future<void> add({
    required String id,
    required String title,
    DateTime? planned,
    DateTime? deadline,
    DateTime? start,
    DateTime? end,
    bool completed = false,
  }) async {
    var task = Task(
      id: id,
      title: title,
      priority: TaskPriority.important,
      estimatedMinutes: 60,
      plannedDate: planned,
      deadline: deadline,
      scheduledStart: start,
      scheduledEnd: end,
      createdAt: time(27, 8),
    );

    if (completed) {
      task = task.markCompleted(time(27, 9));
    }

    await provider.addTask(task);
  }

  test('today contains planned today task', () async {
    await add(id: '1', title: 'Today', planned: time(27, 0));

    expect(provider.plannerToday(now: time(27, 12)).single.id, '1');
  });

  test('overdue task appears in today', () async {
    await add(id: '1', title: 'Missed', planned: time(26, 0));

    expect(provider.plannerToday(now: time(27, 12)).single.id, '1');
  });

  test('future task appears only in upcoming', () async {
    await add(id: '1', title: 'Tomorrow', planned: time(28, 0));

    expect(provider.plannerToday(now: time(27, 12)), isEmpty);

    expect(provider.plannerUpcoming(now: time(27, 12)).single.id, '1');
  });

  test('task without dates appears in backlog', () async {
    await add(id: '1', title: 'Someday');

    expect(provider.plannerBacklog(now: time(27, 12)).single.id, '1');
  });

  test('completed tasks only appear in completed', () async {
    await add(
      id: '1',
      title: 'Finished',
      planned: time(27, 0),
      completed: true,
    );

    expect(provider.plannerToday(now: time(27, 12)), isEmpty);

    expect(provider.plannerUpcoming(now: time(27, 12)), isEmpty);

    expect(provider.plannerBacklog(now: time(27, 12)), isEmpty);

    expect(provider.plannerCompleted().single.id, '1');
  });

  test('active scheduled task is shown first today', () async {
    await add(id: 'normal', title: 'Normal', planned: time(27, 0));

    await add(
      id: 'active',
      title: 'Active',
      start: time(27, 10),
      end: time(27, 11),
    );

    final result = provider.plannerToday(now: time(27, 10, 30));

    expect(result.first.id, 'active');
  });
}

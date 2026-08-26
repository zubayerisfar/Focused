import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/task.dart';

void main() {
  test('deadline stored at end of selected day', () {
    final selectedDate = DateTime(2026, 8, 28);

    final deadline = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      23,
      59,
      59,
      999,
      999,
    );

    expect(deadline.day, 28);

    expect(deadline.hour, 23);

    expect(deadline.minute, 59);
  });

  test('valid scheduled start and end are accepted', () {
    final start = DateTime(2026, 8, 28, 14, 0);

    final end = DateTime(2026, 8, 28, 15, 0);

    expect(end.isAfter(start), isTrue);
  });

  test('scheduled end before start is invalid', () {
    final start = DateTime(2026, 8, 28, 15, 0);

    final end = DateTime(2026, 8, 28, 14, 0);

    expect(end.isAfter(start), isFalse);
  });

  test('task created with planned date keeps planned date', () {
    final plannedDate = DateTime(2026, 8, 28);

    final task = Task(
      id: '1',
      title: 'Study Flutter',
      priority: TaskPriority.critical,
      estimatedMinutes: 60,
      plannedDate: plannedDate,
      createdAt: DateTime(2026, 8, 27),
    );

    expect(task.plannedDate, plannedDate);
  });

  test('scheduled task requires start and end together', () {
    expect(
      () => Task(
        id: '1',
        title: 'Study Flutter',
        priority: TaskPriority.important,
        estimatedMinutes: 60,
        scheduledStart: DateTime(2026, 8, 28, 14),
        scheduledEnd: null,
        createdAt: DateTime(2026, 8, 27),
      ),
      throwsArgumentError,
    );
  });

  test('scheduled end must be after scheduled start', () {
    expect(
      () => Task(
        id: '1',
        title: 'Study Flutter',
        priority: TaskPriority.important,
        estimatedMinutes: 60,
        scheduledStart: DateTime(2026, 8, 28, 15),
        scheduledEnd: DateTime(2026, 8, 28, 14),
        createdAt: DateTime(2026, 8, 27),
      ),
      throwsArgumentError,
    );
  });
}

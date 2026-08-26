import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/task.dart';

void main() {
  test('Task survives toMap and fromMap without losing data', () {
    final original = Task(
      id: 'task-123',
      title: 'Study Flutter',
      description: 'Learn local persistence',
      priority: TaskPriority.critical,
      estimatedMinutes: 90,
      plannedDate: DateTime(2026, 8, 28),
      deadline: DateTime(2026, 8, 30, 23, 59),
      scheduledStart: DateTime(2026, 8, 28, 14),
      scheduledEnd: DateTime(2026, 8, 28, 15, 30),
      createdAt: DateTime(2026, 8, 27, 10),
    );

    final stored = original.toMap();

    final restored = Task.fromMap(stored);

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.description, original.description);
    expect(restored.priority, original.priority);
    expect(restored.estimatedMinutes, original.estimatedMinutes);
    expect(restored.plannedDate, original.plannedDate);
    expect(restored.deadline, original.deadline);
    expect(restored.scheduledStart, original.scheduledStart);
    expect(restored.scheduledEnd, original.scheduledEnd);
    expect(restored.createdAt, original.createdAt);
    expect(restored.isCompleted, isFalse);
  });

  test('completed task survives serialization', () {
    final original = Task(
      id: 'task-complete',
      title: 'Finish report',
      priority: TaskPriority.important,
      estimatedMinutes: 30,
      createdAt: DateTime(2026, 8, 27, 10),
    ).markCompleted(DateTime(2026, 8, 27, 11));

    final restored = Task.fromMap(original.toMap());

    expect(restored.isCompleted, isTrue);

    expect(restored.completedAt, DateTime(2026, 8, 27, 11));
  });
}

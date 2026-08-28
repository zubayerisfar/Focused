import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/providers/task_provider.dart';

void main() {
  Task recurringTask({
    String id = 'daily',
    TaskRecurrence recurrence = TaskRecurrence.daily,
    Set<int> customWeekdays = const {},
    DateTime? start,
    DateTime? end,
  }) {
    final scheduledStart =
        start ?? DateTime(2026, 8, 27, 19);
    final scheduledEnd =
        end ?? DateTime(2026, 8, 27, 20);

    return Task(
      id: id,
      title: id,
      priority: TaskPriority.important,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      createdAt: DateTime(2026, 8, 20),
    );
  }

  test('completing daily occurrence does not complete master', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
      completedAt: DateTime(2026, 8, 27, 20),
    );

    expect(provider.getTaskById(task.id)!.isCompleted, isFalse);
    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 27),
      ),
      isTrue,
    );
  });

  test('daily completion affects only one occurrence date', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 27),
      ),
      isTrue,
    );
    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 28),
      ),
      isFalse,
    );
  });

  test('undo removes only selected occurrence completion', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);

    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 28),
      true,
    );
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      false,
    );

    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 27),
      ),
      isFalse,
    );
    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 28),
      ),
      isTrue,
    );
  });


  test('weekly completion affects only the selected week', () async {
    final provider = TaskProvider();
    final task = recurringTask(
      id: 'weekly',
      recurrence: TaskRecurrence.weekly,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 27),
      ),
      isTrue,
    );
    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 9, 3),
      ),
      isFalse,
    );
  });

  test('weekday completion affects only the selected weekday', () async {
    final provider = TaskProvider();
    final task = recurringTask(
      id: 'weekdays-isolated',
      recurrence: TaskRecurrence.weekdays,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 28),
      true,
    );

    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 28),
      ),
      isTrue,
    );
    expect(
      provider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 31),
      ),
      isFalse,
    );
  });

  test('custom recurrence completion is isolated by date', () async {
    final provider = TaskProvider();
    final task = recurringTask(
      id: 'm-w-f',
      recurrence: TaskRecurrence.customDays,
      customWeekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
      start: DateTime(2026, 8, 28, 19),
      end: DateTime(2026, 8, 28, 20),
    );

    await provider.addTask(task);

    final monday = DateTime(2026, 8, 31);
    final wednesday = DateTime(2026, 9, 2);

    await provider.setCompletedForDate(
      task.id,
      monday,
      true,
    );

    expect(
      provider.isOccurrenceCompleted(task.id, monday),
      isTrue,
    );
    expect(
      provider.isOccurrenceCompleted(task.id, wednesday),
      isFalse,
    );
  });

  test('cannot complete a date when recurrence does not occur', () async {
    final provider = TaskProvider();
    final task = recurringTask(
      id: 'weekdays',
      recurrence: TaskRecurrence.weekdays,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    await provider.addTask(task);

    await expectLater(
      provider.setCompletedForDate(
        task.id,
        DateTime(2026, 8, 29),
        true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('direct master completion is rejected for recurring task', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);

    await expectLater(
      provider.setCompleted(
        task.id,
        true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('one-time completion behavior remains unchanged', () async {
    final provider = TaskProvider();

    final task = Task(
      id: 'one-time',
      title: 'One time',
      priority: TaskPriority.critical,
      plannedDate: DateTime(2026, 8, 27),
      createdAt: DateTime(2026, 8, 27, 8),
    );

    await provider.addTask(task);

    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
      completedAt: DateTime(2026, 8, 27, 10),
    );

    final completed = provider.getTaskById(task.id)!;

    expect(completed.isCompleted, isTrue);
    expect(
      completed.completedAt,
      DateTime(2026, 8, 27, 10),
    );
  });

  test('scheduled occurrence exposes date-specific completion state', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 28),
      true,
      completedAt: DateTime(2026, 8, 28, 20),
    );

    final aug27 = provider.scheduledOccurrencesForDate(
      DateTime(2026, 8, 27),
    );
    final aug28 = provider.scheduledOccurrencesForDate(
      DateTime(2026, 8, 28),
    );

    expect(aug27.single.isCompleted, isFalse);
    expect(aug28.single.isCompleted, isTrue);
    expect(
      aug28.single.completedAt,
      DateTime(2026, 8, 28, 20),
    );
  });

  test('includeCompleted false hides only completed occurrence', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    expect(
      provider.scheduledOccurrencesForDate(
        DateTime(2026, 8, 27),
        includeCompleted: false,
      ),
      isEmpty,
    );

    expect(
      provider.scheduledOccurrencesForDate(
        DateTime(2026, 8, 28),
        includeCompleted: false,
      ),
      hasLength(1),
    );
  });

  test('nextTask ignores a completed recurring occurrence today', () async {
    final provider = TaskProvider();
    final task = recurringTask(
      start: DateTime(2026, 8, 27, 9),
      end: DateTime(2026, 8, 27, 11),
    );

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    expect(
      provider.nextTask(
        now: DateTime(2026, 8, 27, 10),
      ),
      isNull,
    );
  });

  test('completed recurring occurrences are exposed as history', () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 28),
      true,
      completedAt: DateTime(2026, 8, 28, 20, 5),
    );

    final history = provider.completedRecurringOccurrences();

    expect(history, hasLength(1));
    expect(history.single.task.id, task.id);
    expect(history.single.start, DateTime(2026, 8, 28, 19));
    expect(history.single.isCompleted, isTrue);
    expect(
      history.single.completedAt,
      DateTime(2026, 8, 28, 20, 5),
    );
  });



  test('past completion remains visible after recurrence pattern edit',
      () async {
    final provider = TaskProvider();
    final task = recurringTask(
      id: 'edited-pattern',
      recurrence: TaskRecurrence.daily,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 28),
      true,
      completedAt: DateTime(2026, 8, 28, 20),
    );

    final edited = Task(
      id: task.id,
      title: task.title,
      priority: task.priority,
      scheduledStart: task.scheduledStart,
      scheduledEnd: task.scheduledEnd,
      recurrence: TaskRecurrence.weekly,
      createdAt: task.createdAt,
    );

    await provider.updateTask(edited);

    final historical = provider.scheduledOccurrencesForDate(
      DateTime(2026, 8, 28),
    );

    expect(historical, hasLength(1));
    expect(historical.single.isCompleted, isTrue);
    expect(
      historical.single.completedAt,
      DateTime(2026, 8, 28, 20),
    );
  });

  test('changing recurring task to one-time clears occurrence history',
      () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    final updated = Task(
      id: task.id,
      title: task.title,
      priority: task.priority,
      plannedDate: DateTime(2026, 8, 28),
      createdAt: task.createdAt,
    );

    await provider.updateTask(updated);

    expect(provider.occurrenceCompletions, isEmpty);
    expect(provider.getTaskById(task.id)!.recurrence, TaskRecurrence.none);
  });

  test('deleting recurring series removes completion history in memory',
      () async {
    final provider = TaskProvider();
    final task = recurringTask();

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    await provider.deleteTask(task.id);

    expect(provider.getTaskById(task.id), isNull);
    expect(provider.occurrenceCompletions, isEmpty);
    expect(provider.completedRecurringOccurrences(), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/services/task_schedule_service.dart';

void main() {
  const service = TaskScheduleService();

  Task task({
    required TaskRecurrence recurrence,
    required DateTime start,
    required DateTime end,
    Set<int> customWeekdays = const {},
  }) {
    return Task(
      id: 'task',
      title: 'Task',
      priority: TaskPriority.important,
      scheduledStart: start,
      scheduledEnd: end,
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      createdAt: start,
    );
  }

  test('daily recurrence starts on anchor date and repeats after it', () {
    final value = task(
      recurrence: TaskRecurrence.daily,
      start: DateTime(2026, 8, 28, 19),
      end: DateTime(2026, 8, 28, 21),
    );

    expect(service.occursOnDate(value, DateTime(2026, 8, 27)), isFalse);
    expect(service.occursOnDate(value, DateTime(2026, 8, 28)), isTrue);
    expect(service.occursOnDate(value, DateTime(2026, 8, 29)), isTrue);
  });

  test('weekdays skips saturday and sunday', () {
    final value = task(
      recurrence: TaskRecurrence.weekdays,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    expect(service.occursOnDate(value, DateTime(2026, 8, 28)), isTrue);
    expect(service.occursOnDate(value, DateTime(2026, 8, 29)), isFalse);
    expect(service.occursOnDate(value, DateTime(2026, 8, 30)), isFalse);
    expect(service.occursOnDate(value, DateTime(2026, 8, 31)), isTrue);
  });

  test('weekly only occurs on anchor weekday', () {
    final value = task(
      recurrence: TaskRecurrence.weekly,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    expect(service.occursOnDate(value, DateTime(2026, 9, 3)), isTrue);
    expect(service.occursOnDate(value, DateTime(2026, 9, 4)), isFalse);
  });

  test('custom days only occur on selected weekdays', () {
    final value = task(
      recurrence: TaskRecurrence.customDays,
      start: DateTime(2026, 8, 28, 19),
      end: DateTime(2026, 8, 28, 20),
      customWeekdays: const {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      },
    );

    expect(service.occursOnDate(value, DateTime(2026, 8, 31)), isTrue);
    expect(service.occursOnDate(value, DateTime(2026, 9, 1)), isFalse);
    expect(service.occursOnDate(value, DateTime(2026, 9, 2)), isTrue);
  });

  test('occurrence keeps original duration on generated day', () {
    final value = task(
      recurrence: TaskRecurrence.daily,
      start: DateTime(2026, 8, 27, 23),
      end: DateTime(2026, 8, 28, 1),
    );

    final occurrence = service.occurrenceForDate(
      value,
      DateTime(2026, 8, 30),
    );

    expect(occurrence, isNotNull);
    expect(occurrence!.start, DateTime(2026, 8, 30, 23));
    expect(occurrence.end, DateTime(2026, 8, 31, 1));
    expect(occurrence.duration, const Duration(hours: 2));
  });

  test('next occurrence is strictly after supplied time', () {
    final value = task(
      recurrence: TaskRecurrence.daily,
      start: DateTime(2026, 8, 27, 19),
      end: DateTime(2026, 8, 27, 20),
    );

    expect(
      service.nextOccurrenceStart(
        value,
        DateTime(2026, 8, 27, 18),
      ),
      DateTime(2026, 8, 27, 19),
    );

    expect(
      service.nextOccurrenceStart(
        value,
        DateTime(2026, 8, 27, 19),
      ),
      DateTime(2026, 8, 28, 19),
    );
  });
}

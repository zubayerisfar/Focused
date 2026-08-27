import 'package:flutter_test/flutter_test.dart';

import '../lib/models/task.dart';
import '../lib/models/task_recurrence.dart';
import '../lib/services/task_schedule_service.dart';

void main() {
  const service = TaskScheduleService();

  Task task({
    required TaskRecurrence recurrence,
    Set<int> customWeekdays = const {},
    DateTime? start,
    DateTime? end,
  }) {
    return Task(
      id: 'task-${recurrence.name}',
      title: 'Code',
      priority: TaskPriority.important,
      estimatedMinutes: 120,
      scheduledStart: start ?? DateTime(2026, 8, 27, 19),
      scheduledEnd: end ?? DateTime(2026, 8, 27, 21),
      recurrence: recurrence,
      customWeekdays: customWeekdays,
      createdAt: DateTime(2026, 8, 27, 10),
    );
  }

  group('TaskScheduleService', () {
    test('one-time task occurs only on anchor date', () {
      final value = task(recurrence: TaskRecurrence.none);

      expect(service.occursOnDate(value, DateTime(2026, 8, 27)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 8, 28)), isFalse);
    });

    test('daily task occurs every day from anchor onward', () {
      final value = task(recurrence: TaskRecurrence.daily);

      expect(service.occursOnDate(value, DateTime(2026, 8, 26)), isFalse);
      expect(service.occursOnDate(value, DateTime(2026, 8, 27)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 8, 30)), isTrue);
    });

    test('weekday task excludes Saturday and Sunday', () {
      final value = task(recurrence: TaskRecurrence.weekdays);

      expect(service.occursOnDate(value, DateTime(2026, 8, 28)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 8, 29)), isFalse);
      expect(service.occursOnDate(value, DateTime(2026, 8, 30)), isFalse);
      expect(service.occursOnDate(value, DateTime(2026, 8, 31)), isTrue);
    });

    test('weekly task repeats on anchor weekday', () {
      final value = task(recurrence: TaskRecurrence.weekly);

      expect(service.occursOnDate(value, DateTime(2026, 8, 27)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 9, 3)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 9, 4)), isFalse);
    });

    test('custom days only occur on selected weekdays', () {
      final value = task(
        recurrence: TaskRecurrence.customDays,
        customWeekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
      );

      expect(service.occursOnDate(value, DateTime(2026, 8, 28)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 8, 29)), isFalse);
      expect(service.occursOnDate(value, DateTime(2026, 8, 31)), isTrue);
      expect(service.occursOnDate(value, DateTime(2026, 9, 2)), isTrue);
    });

    test('generated occurrence keeps original clock time and duration', () {
      final value = task(recurrence: TaskRecurrence.daily);

      final occurrence = service.occurrenceForDate(
        value,
        DateTime(2026, 9, 5),
      );

      expect(occurrence, isNotNull);
      expect(occurrence!.start, DateTime(2026, 9, 5, 19));
      expect(occurrence.end, DateTime(2026, 9, 5, 21));
      expect(occurrence.duration, const Duration(hours: 2));
    });

    test('nextOccurrenceStart skips a same-day occurrence that already passed', () {
      final value = task(recurrence: TaskRecurrence.daily);

      final next = service.nextOccurrenceStart(
        value,
        DateTime(2026, 8, 27, 22),
      );

      expect(next, DateTime(2026, 8, 28, 19));
    });
  });
}

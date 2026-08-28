import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/task_reminder_planner.dart';

void main() {
  const planner = TaskReminderPlanner();

  test('one-time future reminder is scheduled at expected time', () {
    final plan = planner.planOneTime(
      scheduledStart: DateTime(2026, 8, 27, 14, 0),
      scheduledEnd: DateTime(2026, 8, 27, 15, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 13, 0),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 27, 13, 45),
    );
  });

  test('missed one-time reminder shows immediately while task is still relevant', () {
    final plan = planner.planOneTime(
      scheduledStart: DateTime(2026, 8, 27, 14, 0),
      scheduledEnd: DateTime(2026, 8, 27, 15, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 13, 50),
    );

    expect(plan.showNow, isTrue);
    expect(plan.nextReminderAt, isNull);
  });

  test('expired one-time task neither schedules nor shows now', () {
    final plan = planner.planOneTime(
      scheduledStart: DateTime(2026, 8, 27, 14, 0),
      scheduledEnd: DateTime(2026, 8, 27, 15, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 15, 1),
    );

    expect(plan.showNow, isFalse);
    expect(plan.nextReminderAt, isNull);
  });

  test('daily recurrence never schedules before its anchor occurrence', () {
    final plan = planner.planDaily(
      anchorStart: DateTime(2026, 8, 28, 19, 0),
      anchorEnd: DateTime(2026, 8, 28, 21, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 12, 0),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 28, 18, 45),
    );
  });

  test('daily missed reminder shows now and schedules next day', () {
    final plan = planner.planDaily(
      anchorStart: DateTime(2026, 8, 20, 19, 0),
      anchorEnd: DateTime(2026, 8, 20, 21, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 18, 50),
    );

    expect(plan.showNow, isTrue);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 28, 18, 45),
    );
  });

  test('daily task after todays occurrence schedules tomorrow without showing now', () {
    final plan = planner.planDaily(
      anchorStart: DateTime(2026, 8, 20, 19, 0),
      anchorEnd: DateTime(2026, 8, 20, 21, 0),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 22, 0),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 28, 18, 45),
    );
  });

  test('daily reminder can correctly fall on previous calendar day', () {
    final plan = planner.planDaily(
      anchorStart: DateTime(2026, 8, 28, 0, 5),
      anchorEnd: DateTime(2026, 8, 28, 1, 5),
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 23, 40),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 27, 23, 50),
    );
  });

  test('weekly reminder uses requested weekday and anchor clock time', () {
    final plan = planner.planWeeklyDay(
      anchorStart: DateTime(2026, 8, 27, 19, 0),
      anchorEnd: DateTime(2026, 8, 27, 20, 0),
      occurrenceWeekday: DateTime.monday,
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 12, 0),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 31, 18, 45),
    );
  });

  test('weekly reminder crossing midnight is scheduled on previous day', () {
    final plan = planner.planWeeklyDay(
      anchorStart: DateTime(2026, 8, 24, 0, 5),
      anchorEnd: DateTime(2026, 8, 24, 1, 5),
      occurrenceWeekday: DateTime.monday,
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 30, 23, 40),
    );

    expect(plan.showNow, isFalse);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 8, 30, 23, 50),
    );
  });

  test('weekly missed reminder while occurrence is active shows now and keeps next week', () {
    final plan = planner.planWeeklyDay(
      anchorStart: DateTime(2026, 8, 20, 19, 0),
      anchorEnd: DateTime(2026, 8, 20, 21, 0),
      occurrenceWeekday: DateTime.thursday,
      reminderMinutesBefore: 15,
      now: DateTime(2026, 8, 27, 19, 10),
    );

    expect(plan.showNow, isTrue);
    expect(
      plan.nextReminderAt,
      DateTime(2026, 9, 3, 18, 45),
    );
  });

  test('invalid weekday is rejected', () {
    expect(
      () => planner.planWeeklyDay(
        anchorStart: DateTime(2026, 8, 27, 19, 0),
        anchorEnd: DateTime(2026, 8, 27, 20, 0),
        occurrenceWeekday: 8,
        reminderMinutesBefore: 15,
        now: DateTime(2026, 8, 27, 12, 0),
      ),
      throwsArgumentError,
    );
  });
}

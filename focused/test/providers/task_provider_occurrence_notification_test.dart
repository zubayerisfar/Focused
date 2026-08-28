import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/models/task_reminder_result.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/services/task_notification_service.dart';

void main() {
  test('completing today recurring occurrence skips today reminder',
      () async {
    final notifications = _FakeNotificationService();
    final provider = TaskProvider(
      notificationService: notifications,
    );

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      19,
    );
    final task = Task(
      id: 'daily-reminder',
      title: 'Daily reminder',
      priority: TaskPriority.important,
      scheduledStart: todayStart,
      scheduledEnd: todayStart.add(const Duration(hours: 1)),
      recurrence: TaskRecurrence.daily,
      reminderMinutesBefore: 0,
      createdAt: now.subtract(const Duration(days: 3)),
    );

    await provider.addTask(task);
    notifications.scheduled.clear();

    await provider.setCompletedForDate(
      task.id,
      now,
      true,
      completedAt: now,
    );

    expect(notifications.scheduled, hasLength(1));

    final rescheduled = notifications.scheduled.single;
    final expectedNextDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    );

    expect(
      DateTime(
        rescheduled.scheduledStart!.year,
        rescheduled.scheduledStart!.month,
        rescheduled.scheduledStart!.day,
      ),
      expectedNextDay,
    );
  });

  test('undoing today recurring completion restores normal reminder',
      () async {
    final notifications = _FakeNotificationService();
    final provider = TaskProvider(
      notificationService: notifications,
    );

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      19,
    );
    final task = Task(
      id: 'undo-reminder',
      title: 'Undo reminder',
      priority: TaskPriority.important,
      scheduledStart: todayStart,
      scheduledEnd: todayStart.add(const Duration(hours: 1)),
      recurrence: TaskRecurrence.daily,
      reminderMinutesBefore: 0,
      createdAt: now.subtract(const Duration(days: 3)),
    );

    await provider.addTask(task);

    await provider.setCompletedForDate(
      task.id,
      now,
      true,
      completedAt: now,
    );

    notifications.scheduled.clear();

    await provider.setCompletedForDate(
      task.id,
      now,
      false,
    );

    expect(notifications.scheduled, hasLength(1));
    expect(
      notifications.scheduled.single.scheduledStart,
      task.scheduledStart,
    );
  });
}

class _FakeNotificationService extends TaskNotificationService {
  final List<Task> scheduled = <Task>[];
  final List<String> cancelled = <String>[];

  @override
  Future<TaskReminderScheduleResult> scheduleForTask(
    Task task,
  ) async {
    scheduled.add(task);

    return TaskReminderScheduleResult(
      taskId: task.id,
      status: TaskReminderScheduleStatus.scheduledExact,
      message: 'scheduled',
      notificationPermissionGranted: true,
      exactAlarmPermissionGranted: true,
      shownImmediately: false,
      pendingRequestCount: 1,
    );
  }

  @override
  Future<void> cancelForTask(String taskId) async {
    cancelled.add(taskId);
  }
}

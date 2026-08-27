import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/task.dart';
import 'package:focused/models/task_reminder_result.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/services/task_notification_service.dart';

class _FakeNotificationService extends TaskNotificationService {
  TaskReminderScheduleResult nextResult =
      const TaskReminderScheduleResult(
    taskId: 'unset',
    status: TaskReminderScheduleStatus.scheduledExact,
    message: 'scheduled',
    notificationPermissionGranted: true,
    exactAlarmPermissionGranted: true,
    shownImmediately: false,
    pendingRequestCount: 1,
  );

  final List<String> cancelled = [];
  final List<String> scheduled = [];

  @override
  Future<TaskReminderScheduleResult> scheduleForTask(Task task) async {
    scheduled.add(task.id);

    return TaskReminderScheduleResult(
      taskId: task.id,
      status: nextResult.status,
      message: nextResult.message,
      notificationPermissionGranted:
          nextResult.notificationPermissionGranted,
      exactAlarmPermissionGranted:
          nextResult.exactAlarmPermissionGranted,
      shownImmediately: nextResult.shownImmediately,
      pendingRequestCount: nextResult.pendingRequestCount,
      scheduledReminderTimes: nextResult.scheduledReminderTimes,
    );
  }

  @override
  Future<void> cancelForTask(String taskId) async {
    cancelled.add(taskId);
  }

  @override
  Future<bool> sendTestNotification() async => true;

  @override
  Future<int> pendingReminderCount() async => 3;
}

void main() {
  test('provider exposes successful reminder result after creating task', () async {
    final notifications = _FakeNotificationService();
    final provider = TaskProvider(
      notificationService: notifications,
    );

    final task = await provider.createTask(
      title: 'Code',
      priority: TaskPriority.important,
      plannedDate: DateTime(2026, 8, 27),
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 20),
      recurrence: TaskRecurrence.daily,
      reminderMinutesBefore: 15,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    expect(notifications.scheduled, contains(task.id));
    expect(provider.lastReminderResult, isNotNull);
    expect(provider.lastReminderResult!.taskId, task.id);
    expect(provider.lastReminderResult!.isScheduled, isTrue);
  });

  test('provider keeps permission-denied result instead of silently losing it', () async {
    final notifications = _FakeNotificationService()
      ..nextResult = const TaskReminderScheduleResult(
        taskId: 'unset',
        status: TaskReminderScheduleStatus.permissionDenied,
        message: 'permission denied',
        notificationPermissionGranted: false,
        exactAlarmPermissionGranted: false,
        shownImmediately: false,
        pendingRequestCount: 0,
      );

    final provider = TaskProvider(
      notificationService: notifications,
    );

    final task = await provider.createTask(
      title: 'Study',
      priority: TaskPriority.important,
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 19, 30),
      reminderMinutesBefore: 5,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    expect(provider.lastReminderResult!.taskId, task.id);
    expect(
      provider.lastReminderResult!.status,
      TaskReminderScheduleStatus.permissionDenied,
    );
    expect(provider.lastReminderResult!.requiresUserAttention, isTrue);
  });

  test('completing a task cancels its reminder', () async {
    final notifications = _FakeNotificationService();
    final provider = TaskProvider(
      notificationService: notifications,
    );

    final task = await provider.createTask(
      title: 'Read',
      priority: TaskPriority.growth,
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 19, 30),
      reminderMinutesBefore: 5,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    await provider.setCompleted(
      task.id,
      true,
      time: DateTime(2026, 8, 27, 18),
    );

    expect(notifications.cancelled, contains(task.id));
  });

  test('provider diagnostics delegate to notification service', () async {
    final notifications = _FakeNotificationService();
    final provider = TaskProvider(
      notificationService: notifications,
    );

    expect(await provider.sendTestNotification(), isTrue);
    expect(await provider.pendingReminderCount(), 3);
  });
}

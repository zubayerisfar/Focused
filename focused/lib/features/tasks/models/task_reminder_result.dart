enum TaskReminderScheduleStatus {
  noReminder,
  scheduledExact,
  scheduledInexact,
  shownImmediately,
  scheduledExactAndShownImmediately,
  scheduledInexactAndShownImmediately,
  permissionDenied,
  expired,
  error,
}

class TaskReminderScheduleResult {
  final String taskId;
  final TaskReminderScheduleStatus status;
  final String message;
  final bool notificationPermissionGranted;
  final bool exactAlarmPermissionGranted;
  final bool shownImmediately;
  final int pendingRequestCount;
  final List<DateTime> scheduledReminderTimes;

  const TaskReminderScheduleResult({
    required this.taskId,
    required this.status,
    required this.message,
    required this.notificationPermissionGranted,
    required this.exactAlarmPermissionGranted,
    required this.shownImmediately,
    required this.pendingRequestCount,
    this.scheduledReminderTimes = const [],
  });

  bool get isScheduled =>
      status == TaskReminderScheduleStatus.scheduledExact ||
      status == TaskReminderScheduleStatus.scheduledInexact ||
      status == TaskReminderScheduleStatus.scheduledExactAndShownImmediately ||
      status == TaskReminderScheduleStatus.scheduledInexactAndShownImmediately;

  bool get usedExactScheduling =>
      status == TaskReminderScheduleStatus.scheduledExact ||
      status == TaskReminderScheduleStatus.scheduledExactAndShownImmediately;

  bool get requiresUserAttention =>
      status == TaskReminderScheduleStatus.permissionDenied ||
      status == TaskReminderScheduleStatus.scheduledInexact ||
      status == TaskReminderScheduleStatus.scheduledInexactAndShownImmediately ||
      status == TaskReminderScheduleStatus.expired ||
      status == TaskReminderScheduleStatus.error;

  factory TaskReminderScheduleResult.error({
    required String taskId,
    required String message,
  }) {
    return TaskReminderScheduleResult(
      taskId: taskId,
      status: TaskReminderScheduleStatus.error,
      message: message,
      notificationPermissionGranted: false,
      exactAlarmPermissionGranted: false,
      shownImmediately: false,
      pendingRequestCount: 0,
    );
  }
}

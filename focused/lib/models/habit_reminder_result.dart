enum HabitReminderScheduleStatus {
  noReminder,
  scheduledExact,
  scheduledInexact,
  permissionDenied,
  error,
}

class HabitReminderScheduleResult {
  final String habitId;
  final HabitReminderScheduleStatus status;
  final String message;
  final bool notificationPermissionGranted;
  final bool exactAlarmPermissionGranted;
  final int pendingRequestCount;
  final List<DateTime> scheduledReminderTimes;

  const HabitReminderScheduleResult({
    required this.habitId,
    required this.status,
    required this.message,
    required this.notificationPermissionGranted,
    required this.exactAlarmPermissionGranted,
    required this.pendingRequestCount,
    this.scheduledReminderTimes = const [],
  });

  bool get isSuccess =>
      status == HabitReminderScheduleStatus.noReminder ||
      status == HabitReminderScheduleStatus.scheduledExact ||
      status == HabitReminderScheduleStatus.scheduledInexact;

  bool get hasReminderScheduled =>
      status == HabitReminderScheduleStatus.scheduledExact ||
      status == HabitReminderScheduleStatus.scheduledInexact;

  factory HabitReminderScheduleResult.noReminder(String habitId) {
    return HabitReminderScheduleResult(
      habitId: habitId,
      status: HabitReminderScheduleStatus.noReminder,
      message: 'This habit does not currently have a reminder.',
      notificationPermissionGranted: true,
      exactAlarmPermissionGranted: true,
      pendingRequestCount: 0,
    );
  }

  factory HabitReminderScheduleResult.error({
    required String habitId,
    required String message,
  }) {
    return HabitReminderScheduleResult(
      habitId: habitId,
      status: HabitReminderScheduleStatus.error,
      message: message,
      notificationPermissionGranted: false,
      exactAlarmPermissionGranted: false,
      pendingRequestCount: 0,
    );
  }
}

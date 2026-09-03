import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../models/task_reminder_result.dart';
import 'task_reminder_planner.dart';

class TaskNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;
  final TaskReminderPlanner _planner;

  bool _initialized = false;
  String? _timeZoneName;

  TaskNotificationService({
    FlutterLocalNotificationsPlugin? notifications,
    TaskReminderPlanner planner = const TaskReminderPlanner(),
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _planner = planner;

  String? get timeZoneName => _timeZoneName;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    final deviceTimeZone = await FlutterTimezone.getLocalTimezone();

    _timeZoneName = deviceTimeZone.identifier;

    try {
      tz.setLocalLocation(tz.getLocation(deviceTimeZone.identifier));
    } catch (error) {
      throw StateError(
        'Focused could not resolve the device timezone '
        '"${deviceTimeZone.identifier}". Reminder scheduling was stopped '
        'instead of silently using the wrong timezone. Error: $error',
      );
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _notifications.initialize(settings);

    _initialized = true;
  }

  Future<TaskReminderScheduleResult> scheduleForTask(Task task) async {
    try {
      await init();

      // Edits must never leave an old reminder behind.
      await cancelForTask(task.id);

      final start = task.scheduledStart;
      final end = task.scheduledEnd;
      final reminderMinutes = task.reminderMinutesBefore;

      if (task.isCompleted ||
          start == null ||
          end == null ||
          reminderMinutes == null) {
        return TaskReminderScheduleResult(
          taskId: task.id,
          status: TaskReminderScheduleStatus.noReminder,
          message: 'This task does not currently need a reminder.',
          notificationPermissionGranted: true,
          exactAlarmPermissionGranted: true,
          shownImmediately: false,
          pendingRequestCount: 0,
        );
      }

      final now = DateTime.now();
      final plan = _buildPlan(
        task: task,
        now: now,
        reminderMinutes: reminderMinutes,
      );

      if (!plan.showNow && plan.schedules.isEmpty) {
        return TaskReminderScheduleResult(
          taskId: task.id,
          status: TaskReminderScheduleStatus.expired,
          message: 'The reminder time and task time have already passed.',
          notificationPermissionGranted: true,
          exactAlarmPermissionGranted: true,
          shownImmediately: false,
          pendingRequestCount: 0,
        );
      }

      final notificationPermissionGranted =
          await _requestNotificationPermission();

      if (!notificationPermissionGranted) {
        return TaskReminderScheduleResult(
          taskId: task.id,
          status: TaskReminderScheduleStatus.permissionDenied,
          message:
              'Task saved, but Android notification permission is disabled. '
              'Enable notifications for Focused to receive reminders.',
          notificationPermissionGranted: false,
          exactAlarmPermissionGranted: false,
          shownImmediately: false,
          pendingRequestCount: 0,
        );
      }

      var shownImmediately = false;

      if (plan.showNow) {
        await _showImmediateReminder(task, reminderMinutes);
        shownImmediately = true;
      }

      var exactAlarmPermissionGranted = true;
      var useExactScheduling = true;

      if (plan.schedules.isNotEmpty) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (android != null) {
          exactAlarmPermissionGranted =
              await android.requestExactAlarmsPermission() ?? false;

          useExactScheduling = exactAlarmPermissionGranted;
        }

        for (final schedule in plan.schedules) {
          await _notifications.zonedSchedule(
            _notificationId(task.id, schedule.slot),
            _engagingTaskTitle(task),
            _engagingTaskBody(task, reminderMinutes),
            _toLocalTz(schedule.firstReminderAt),
            _details,
            androidScheduleMode: useExactScheduling
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: schedule.matchDateTimeComponents,
            payload: task.id,
          );
        }
      }

      final pendingCount = await pendingReminderCountForTask(task.id);

      if (plan.schedules.isNotEmpty && pendingCount == 0) {
        return TaskReminderScheduleResult(
          taskId: task.id,
          status: TaskReminderScheduleStatus.error,
          message:
              'Focused tried to schedule the reminder, but Android reported '
              'no pending reminder afterwards. Check the AndroidManifest '
              'scheduled-notification receivers.',
          notificationPermissionGranted: true,
          exactAlarmPermissionGranted: exactAlarmPermissionGranted,
          shownImmediately: shownImmediately,
          pendingRequestCount: 0,
          scheduledReminderTimes: plan.schedules
              .map((item) => item.firstReminderAt)
              .toList(),
        );
      }

      final status = _successStatus(
        exact: useExactScheduling,
        shownImmediately: shownImmediately,
        hasFutureSchedules: plan.schedules.isNotEmpty,
      );

      final message = useExactScheduling
          ? shownImmediately
                ? 'Reminder shown now and future reminders are scheduled exactly.'
                : 'Reminder scheduled successfully.'
          : shownImmediately
          ? 'Reminder shown now. Future reminders are scheduled, but '
                'Android may deliver them late because exact alarms are disabled.'
          : 'Reminder scheduled, but Android may deliver it late because '
                'exact alarms are disabled.';

      return TaskReminderScheduleResult(
        taskId: task.id,
        status: status,
        message: message,
        notificationPermissionGranted: true,
        exactAlarmPermissionGranted: exactAlarmPermissionGranted,
        shownImmediately: shownImmediately,
        pendingRequestCount: pendingCount,
        scheduledReminderTimes: plan.schedules
            .map((item) => item.firstReminderAt)
            .toList(),
      );
    } catch (error) {
      return TaskReminderScheduleResult.error(
        taskId: task.id,
        message: 'Reminder scheduling failed: $error',
      );
    }
  }

  Future<bool> sendTestNotification() async {
    await init();

    final permissionGranted = await _requestNotificationPermission();

    if (!permissionGranted) {
      return false;
    }

    await _notifications.show(
      2147483000,
      'Focused notification test',
      'If you can see this, immediate notifications are working.',
      _details,
      payload: 'focused_notification_test',
    );

    return true;
  }

  Future<int> pendingReminderCount() async {
    await init();

    final pending = await _notifications.pendingNotificationRequests();

    return pending.length;
  }

  Future<int> pendingReminderCountForTask(String taskId) async {
    await init();

    final expectedIds = <int>{
      for (var slot = 0; slot <= 9; slot++) _notificationId(taskId, slot),
    };

    final pending = await _notifications.pendingNotificationRequests();

    return pending.where((request) => expectedIds.contains(request.id)).length;
  }

  Future<void> cancelForTask(String taskId) async {
    await init();

    for (var slot = 0; slot <= 9; slot++) {
      await _notifications.cancel(_notificationId(taskId, slot));
    }
  }

  Future<void> cancelAllTaskReminders() async {
    await init();
    await _notifications.cancelAll();
  }

  _TaskPlatformPlan _buildPlan({
    required Task task,
    required DateTime now,
    required int reminderMinutes,
  }) {
    final start = task.scheduledStart!;
    final end = task.scheduledEnd!;

    switch (task.recurrence) {
      case TaskRecurrence.none:
        final timing = _planner.planOneTime(
          scheduledStart: start,
          scheduledEnd: end,
          reminderMinutesBefore: reminderMinutes,
          now: now,
        );

        return _TaskPlatformPlan(
          showNow: timing.showNow,
          schedules: timing.nextReminderAt == null
              ? const []
              : [
                  _ReminderSchedule(
                    slot: 0,
                    firstReminderAt: timing.nextReminderAt!,
                  ),
                ],
        );

      case TaskRecurrence.daily:
        final timing = _planner.planDaily(
          anchorStart: start,
          anchorEnd: end,
          reminderMinutesBefore: reminderMinutes,
          now: now,
        );

        return _TaskPlatformPlan(
          showNow: timing.showNow,
          schedules: timing.nextReminderAt == null
              ? const []
              : [
                  _ReminderSchedule(
                    slot: 0,
                    firstReminderAt: timing.nextReminderAt!,
                    matchDateTimeComponents: DateTimeComponents.time,
                  ),
                ],
        );

      case TaskRecurrence.weekly:
        final timing = _planner.planWeeklyDay(
          anchorStart: start,
          anchorEnd: end,
          occurrenceWeekday: start.weekday,
          reminderMinutesBefore: reminderMinutes,
          now: now,
        );

        return _TaskPlatformPlan(
          showNow: timing.showNow,
          schedules: timing.nextReminderAt == null
              ? const []
              : [
                  _ReminderSchedule(
                    slot: 1,
                    firstReminderAt: timing.nextReminderAt!,
                    matchDateTimeComponents:
                        DateTimeComponents.dayOfWeekAndTime,
                  ),
                ],
        );

      case TaskRecurrence.weekdays:
        return _weeklyPatternPlan(
          task: task,
          weekdays: const {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          },
          reminderMinutes: reminderMinutes,
          now: now,
        );

      case TaskRecurrence.customDays:
        return _weeklyPatternPlan(
          task: task,
          weekdays: task.customWeekdays,
          reminderMinutes: reminderMinutes,
          now: now,
        );
    }
  }

  _TaskPlatformPlan _weeklyPatternPlan({
    required Task task,
    required Set<int> weekdays,
    required int reminderMinutes,
    required DateTime now,
  }) {
    final schedules = <_ReminderSchedule>[];
    var showNow = false;

    for (final weekday in weekdays.toList()..sort()) {
      final timing = _planner.planWeeklyDay(
        anchorStart: task.scheduledStart!,
        anchorEnd: task.scheduledEnd!,
        occurrenceWeekday: weekday,
        reminderMinutesBefore: reminderMinutes,
        now: now,
      );

      showNow = showNow || timing.showNow;

      if (timing.nextReminderAt != null) {
        schedules.add(
          _ReminderSchedule(
            // Weekday is already 1...7, which gives
            // every repeating day a stable slot.
            slot: weekday,
            firstReminderAt: timing.nextReminderAt!,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          ),
        );
      }
    }

    return _TaskPlatformPlan(showNow: showNow, schedules: schedules);
  }

  Future<bool> requestNotificationPermission() async {
    await init();
    return _requestNotificationPermission();
  }

  Future<bool?> notificationsEnabled() async {
    await init();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return android.areNotificationsEnabled();
    }
    return null;
  }

  Future<bool> scheduleBirthdayNotification({
    required DateTime birthday,
    required String displayName,
  }) async {
    await init();
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) return false;

    await _notifications.cancel(_birthdayNotificationId);
    final now = tz.TZDateTime.now(tz.local);
    final next = _nextBirthdayOccurrence(birthday: birthday, now: now);

    await _notifications.zonedSchedule(
      _birthdayNotificationId,
      'Happy birthday, ${displayName.trim().isEmpty ? 'Focused User' : displayName.trim()}! 🎉',
      'Have a great day — and remember that rest counts too.',
      next,
      _birthdayDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'birthday',
    );
    return true;
  }

  Future<void> cancelBirthdayNotification() async {
    await init();
    await _notifications.cancel(_birthdayNotificationId);
  }

  tz.TZDateTime _nextBirthdayOccurrence({
    required DateTime birthday,
    required tz.TZDateTime now,
  }) {
    tz.TZDateTime forYear(int year) {
      var day = birthday.day;
      if (birthday.month == DateTime.february &&
          day == 29 &&
          !_isLeapYear(year)) {
        day = 28;
      }
      return tz.TZDateTime(tz.local, year, birthday.month, day, 9);
    }

    var candidate = forYear(now.year);
    if (!candidate.isAfter(now)) {
      candidate = forYear(now.year + 1);
    }
    return candidate;
  }

  bool _isLeapYear(int year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  }

  Future<bool> _requestNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final mac = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    if (mac != null) {
      return await mac.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<void> _showImmediateReminder(Task task, int reminderMinutes) async {
    final title = _engagingTaskTitle(task);
    final body = _engagingTaskBody(task, reminderMinutes);
    await _notifications.show(
      _notificationId(task.id, 9),
      title,
      body,
      _details,
      payload: task.id,
    );
  }

  Future<void> showFriendReminderNotification({
    required String fromName,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'focused_friend_reminders',
      'Friend Task Reminders',
      channelDescription:
          'Notifications sent by your friends to remind you to finish your tasks.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final titleVariations = [
      '🔥 $fromName caught you slacking!',
      '👀 $fromName is watching your streak!',
      '😤 $fromName demands your best today!',
      '⚡ Wake up! $fromName sent you a nudge!',
    ];
    final selectedTitle =
        titleVariations[(fromName.hashCode ^ DateTime.now().minute).abs() %
            titleVariations.length];

    final urgentBody = message.isNotEmpty
        ? message
        : '$fromName says: "Put away the distractions and finish your task right now! No excuses!" 💥';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      selectedTitle,
      urgentBody,
      notificationDetails,
    );
  }

  Future<void> scheduleTaskMateReminder({
    required String groupId,
    required String taskTitle,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'focused_task_mates',
      'Task Mate Reminders',
      channelDescription:
          'Scheduled reminders for your shared Task Mate goals.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final titleList = [
      '⚡ Task Mate Alert: Time to execute!',
      '🔥 Your squad is waiting on "$taskTitle"!',
      '🤝 Task Mate Showdown: Earn +200 EXP now!',
      '😤 Don\'t let your team down! Lock in!',
    ];
    final selectedTitle =
        titleList[(groupId.hashCode ^ taskTitle.hashCode).abs() %
            titleList.length];

    final bodyList = [
      'Your shared squad task "$taskTitle" starts NOW. Finish it to secure your +200 EXP double reward! 🏆',
      'Zero excuses! Lock in on "$taskTitle" right now before your mates finish first! 🚀 (+200 EXP)',
      'Stop procrastinating. Your squad scheduled "$taskTitle" for this moment. Let\'s conquer it! 💪',
    ];
    final selectedBody =
        bodyList[(taskTitle.hashCode ^ scheduledTime.minute).abs() %
            bodyList.length];

    final notifId = (groupId.hashCode ^ taskTitle.hashCode).abs() % 100000;
    try {
      await _notifications.zonedSchedule(
        notifId,
        selectedTitle,
        selectedBody,
        tzDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task_mate_$groupId',
      );
    } catch (e) {
      debugPrint('Could not schedule Task Mate reminder: $e');
    }
  }

  tz.TZDateTime _toLocalTz(DateTime value) {
    // Reconstruct using wall-clock components. The Task model stores the
    // user's local calendar/time choice; converting the instant with
    // TZDateTime.from() can shift the displayed clock if the source DateTime
    // was created under a different local timezone.
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  TaskReminderScheduleStatus _successStatus({
    required bool exact,
    required bool shownImmediately,
    required bool hasFutureSchedules,
  }) {
    if (!hasFutureSchedules && shownImmediately) {
      return TaskReminderScheduleStatus.shownImmediately;
    }

    if (exact) {
      return shownImmediately
          ? TaskReminderScheduleStatus.scheduledExactAndShownImmediately
          : TaskReminderScheduleStatus.scheduledExact;
    }

    return shownImmediately
        ? TaskReminderScheduleStatus.scheduledInexactAndShownImmediately
        : TaskReminderScheduleStatus.scheduledInexact;
  }

  static String _engagingTaskTitle(Task task) {
    final titles = [
      '🔥 Don\'t break your streak! "${task.title}"',
      '⚡ Lock in: "${task.title}" starts now!',
      '⏱️ Time is running out: "${task.title}"',
      '💪 No excuses today: "${task.title}"',
      '🎯 Your future self is watching: "${task.title}"',
    ];
    return titles[(task.id.hashCode ^ task.title.hashCode).abs() %
        titles.length];
  }

  static String _engagingTaskBody(Task task, int reminderMinutes) {
    if (reminderMinutes == 0) {
      final immediate = [
        'Stop scrolling right now. Put away distractions and crush this task! 🚀',
        'Procrastination is the thief of your potential. Get to work right now! 😤',
        'Champions show up even when they don\'t feel like it. Start now! 🔥',
        'You scheduled this for a reason. Prove to yourself you can execute! 💥',
        'Every minute wasted is a minute lost forever. Dive into focus mode! ⚡',
      ];
      return immediate[(task.id.hashCode).abs() % immediate.length];
    }

    final countdown = [
      'Starting in $reminderMinutes mins! Clear your desk, close social media, and get ready! ⏱️',
      'Countdown: $reminderMinutes mins left. Put your phone away and prepare to execute! 🎧',
      'T-minus $reminderMinutes mins until deep work. No excuses, let\'s make today count! 💪',
    ];
    return countdown[(task.id.hashCode ^ reminderMinutes).abs() %
        countdown.length];
  }

  int _notificationId(String taskId, int slot) {
    var hash = 2166136261;

    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    return ((hash % 100000000) * 10 + slot) & 0x7fffffff;
  }

  static const int _birthdayNotificationId = 904220;

  static const NotificationDetails _birthdayDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'birthday_reminders_v1',
      'Birthday reminders',
      channelDescription: 'Birthday reminders from your Focused profile',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders_v2',
      'Task reminders',
      channelDescription: 'Reminders for scheduled Focused tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );
}

class _TaskPlatformPlan {
  final bool showNow;
  final List<_ReminderSchedule> schedules;

  const _TaskPlatformPlan({required this.showNow, required this.schedules});
}

class _ReminderSchedule {
  final int slot;
  final DateTime firstReminderAt;
  final DateTimeComponents? matchDateTimeComponents;

  const _ReminderSchedule({
    required this.slot,
    required this.firstReminderAt,
    this.matchDateTimeComponents,
  });
}

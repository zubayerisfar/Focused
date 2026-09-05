import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import '../models/habit_reminder_result.dart';
import 'habit_reminder_planner.dart';

abstract class HabitReminderScheduler {
  Future<HabitReminderScheduleResult> scheduleForHabit(Habit habit);
  Future<void> cancelForHabit(String habitId);
  Future<int> pendingReminderCountForHabit(String habitId);
  Future<void> cancelAllHabitReminders();
}

class HabitNotificationService implements HabitReminderScheduler {
  final FlutterLocalNotificationsPlugin _notifications;
  final HabitReminderPlanner _planner;

  bool _initialized = false;
  String? _timeZoneName;

  HabitNotificationService({
    FlutterLocalNotificationsPlugin? notifications,
    HabitReminderPlanner planner = const HabitReminderPlanner(),
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _planner = planner;

  String? get timeZoneName => _timeZoneName;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    _timeZoneName = deviceTimeZone.identifier;

    try {
      tz.setLocalLocation(tz.getLocation(deviceTimeZone.identifier));
    } catch (error) {
      throw StateError(
        'Focused could not resolve the device timezone '
        '"${deviceTimeZone.identifier}" for habit reminders. Error: $error',
      );
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
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

  @override
  Future<HabitReminderScheduleResult> scheduleForHabit(Habit habit) async {
    try {
      await init();
      await cancelForHabit(habit.id);

      final minutes = habit.reminderMinutesFromMidnight;
      if (minutes == null) {
        return HabitReminderScheduleResult.noReminder(habit.id);
      }

      final permissionGranted = await _requestNotificationPermission();
      if (!permissionGranted) {
        return HabitReminderScheduleResult(
          habitId: habit.id,
          status: HabitReminderScheduleStatus.permissionDenied,
          message:
              'Habit saved, but notification permission is disabled. Enable notifications for Focused to receive habit reminders.',
          notificationPermissionGranted: false,
          exactAlarmPermissionGranted: false,
          pendingRequestCount: 0,
        );
      }

      var exactAlarmPermissionGranted = true;
      var useExactScheduling = true;

      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        exactAlarmPermissionGranted =
            await android.requestExactAlarmsPermission() ?? false;
        useExactScheduling = exactAlarmPermissionGranted;
      }

      final now = DateTime.now();
      final weekdays = habit.weekdays.toList()..sort();
      final scheduled = _planner.planSelectedWeekdays(
        now: now,
        weekdays: habit.weekdays,
        minutesFromMidnight: minutes,
      );

      for (var index = 0; index < weekdays.length; index++) {
        final weekday = weekdays[index];
        final next = scheduled[index];

        await _notifications.zonedSchedule(
          _notificationId(habit.id, weekday),
          habit.title,
          _body(habit),
          _toLocalTz(next),
          _details,
          androidScheduleMode: useExactScheduling
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'habit:${habit.id}',
        );

        if (habit.lateReminderMinutesAfter != null &&
            habit.lateReminderMinutesAfter! > 0) {
          final lateTime = next.add(
            Duration(minutes: habit.lateReminderMinutesAfter!),
          );
          await _notifications.zonedSchedule(
            _lateNotificationId(habit.id, weekday),
            '⏳ Don\'t forget: ${habit.title}',
            'Did you finish "${habit.title}" today? Check it off now to keep your streak!',
            _toLocalTz(lateTime),
            _details,
            androidScheduleMode: useExactScheduling
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'habit_late:${habit.id}',
          );
        }
      }

      final pendingCount = await pendingReminderCountForHabit(habit.id);

      final expectedMin = weekdays.length;
      if (pendingCount < expectedMin) {
        await cancelForHabit(habit.id);
        return HabitReminderScheduleResult.error(
          habitId: habit.id,
          message:
              'Focused could not verify every habit reminder after scheduling. No partial reminder set was kept.',
        );
      }

      return HabitReminderScheduleResult(
        habitId: habit.id,
        status: useExactScheduling
            ? HabitReminderScheduleStatus.scheduledExact
            : HabitReminderScheduleStatus.scheduledInexact,
        message: useExactScheduling
            ? 'Habit reminder scheduled successfully.'
            : 'Habit reminder scheduled. Android may deliver it slightly late because exact alarms are disabled.',
        notificationPermissionGranted: true,
        exactAlarmPermissionGranted: exactAlarmPermissionGranted,
        pendingRequestCount: pendingCount,
        scheduledReminderTimes: scheduled,
      );
    } catch (error) {
      try {
        await cancelForHabit(habit.id);
      } catch (_) {
        // Keep the original scheduling error as the primary result.
      }
      return HabitReminderScheduleResult.error(
        habitId: habit.id,
        message: 'Habit reminder scheduling failed: $error',
      );
    }
  }

  @override
  Future<void> cancelForHabit(String habitId) async {
    await init();
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _notifications.cancel(_notificationId(habitId, weekday));
      await _notifications.cancel(_lateNotificationId(habitId, weekday));
    }
  }

  @override
  Future<void> cancelAllHabitReminders() async {
    await init();
    await _notifications.cancelAll();
  }

  @override
  Future<int> pendingReminderCountForHabit(String habitId) async {
    await init();
    final expected = <int>{
      for (
        var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) ...[
        _notificationId(habitId, weekday),
        _lateNotificationId(habitId, weekday),
      ],
    };

    final pending = await _notifications.pendingNotificationRequests();
    return pending.where((request) => expected.contains(request.id)).length;
  }

  tz.TZDateTime _toLocalTz(DateTime value) {
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    );
  }

  Future<bool> _requestNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
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

  String _body(Habit habit) {
    final habitMessages = [
      'Discipline over motivation! Crush your "${habit.title}" habit now before the day ends! 🔥',
      'Don\'t break your habit streak. Take 5 minutes for "${habit.title}" right now! ⚡',
      'Winners build daily habits. Lock in for "${habit.title}" today! 💪',
      'Small habits lead to giant success. Put distractions away and do "${habit.title}"! 🎯',
      'Your future self will thank you. Complete "${habit.title}" now! 🚀',
    ];
    return habitMessages[habit.id.hashCode.abs() % habitMessages.length];
  }

  int _notificationId(String habitId, int weekday) {
    var hash = 2166136261;
    for (final unit in habitId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    // Keep habit reminder IDs in a separate range from task reminder IDs.
    return 1100000000 + ((hash % 100000000) * 7) + weekday;
  }

  int _lateNotificationId(String habitId, int weekday) {
    var hash = 2166136261;
    for (final unit in habitId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    return 1200000000 + ((hash % 100000000) * 7) + weekday;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders_v1',
      'Habit reminders',
      channelDescription: 'Reminders for repeating Focused habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('notif_habit_reminder'),
      color: Color(0xFF4E25AA),
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  Future<void> scheduleStreakContinuationReminder({
    required int streakDays,
    required int hour,
    required int minute,
  }) async {
    const reminderId = 776655;
    await _notifications.cancel(reminderId);

    const streakDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'focused_streak_reminders_v1',
        'Streak Continuity Reminders',
        channelDescription:
            'Alerts to protect and continue your active habit streak.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('notif_streak'),
        color: Color(0xFF4E25AA),
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _notifications.zonedSchedule(
        reminderId,
        '🔥 Keep your $streakDays-day streak alive!',
        'You have active habits waiting today. Check them off before midnight.',
        scheduled,
        streakDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'streak_continue_reminder',
      );
    } catch (e) {
      // Ignored if timezone error
    }
  }

  Future<void> cancelStreakContinuationReminder() async {
    const reminderId = 776655;
    await _notifications.cancel(reminderId);
  }
}

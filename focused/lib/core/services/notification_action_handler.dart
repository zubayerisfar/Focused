import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../features/habits/models/habit_progress.dart';
import '../../features/habits/providers/habit_provider.dart';
import '../../features/habits/services/habit_storage_service.dart';
import '../../features/tasks/models/task_occurrence_completion.dart';
import '../../features/tasks/models/task_recurrence.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../../features/tasks/services/task_occurrence_completion_storage_service.dart';
import '../../features/tasks/services/task_storage_service.dart';

/// Top-level entry point for background notification actions.
/// Must be annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationActionHandler.handleAction(response, isBackground: true);
}

class NotificationActionHandler {
  static const String actionMarkDoneTask = 'mark_done_task';
  static const String actionMarkDoneHabit = 'mark_done_habit';

  // Global references to providers when app is running in the foreground
  static TaskProvider? taskProvider;
  static HabitProvider? habitProvider;

  /// Handles notification response whether coming from foreground or background.
  static Future<void> handleAction(
    NotificationResponse response, {
    bool isBackground = false,
  }) async {
    final actionId = response.actionId;
    final payload = response.payload;

    debugPrint(
      'NotificationActionHandler: actionId=$actionId, payload=$payload, isBackground=$isBackground',
    );

    if (actionId == null || actionId.isEmpty) {
      // User tapped the notification itself (not an action button)
      return;
    }

    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      if (actionId == actionMarkDoneTask) {
        await _handleTaskMarkDone(payload, isBackground: isBackground);
      } else if (actionId == actionMarkDoneHabit) {
        await _handleHabitMarkDone(payload, isBackground: isBackground);
      }
    } catch (e, stack) {
      debugPrint('NotificationActionHandler error handling action: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  static Future<void> _handleTaskMarkDone(
    String payload, {
    required bool isBackground,
  }) async {
    // Payload can be taskId, task:taskId, or late_taskId
    var taskId = payload;
    if (taskId.startsWith('task:')) {
      taskId = taskId.substring(5);
    } else if (taskId.startsWith('late_')) {
      taskId = taskId.substring(5);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If app is live in foreground and TaskProvider is attached, use it directly
    final currentTaskProvider = taskProvider;
    if (!isBackground && currentTaskProvider != null) {
      final task = currentTaskProvider.getTaskById(taskId);
      if (task != null) {
        if (task.recurrence == TaskRecurrence.none) {
          await currentTaskProvider.setCompleted(taskId, true, time: now);
        } else {
          await currentTaskProvider.setCompletedForDate(
            taskId,
            today,
            true,
            completedAt: now,
          );
        }
        return;
      }
    }

    // Otherwise or in background, perform direct Hive operations
    await Hive.initFlutter();

    final taskStorage = TaskStorageService();
    await taskStorage.init();

    final task = taskStorage.loadTask(taskId);
    if (task == null) {
      debugPrint('Task not found in storage: $taskId');
      return;
    }

    if (task.recurrence == TaskRecurrence.none) {
      final updated = task.markCompleted(now);
      await taskStorage.saveTask(updated);
    } else {
      final occurrenceStorage = TaskOccurrenceCompletionStorageService();
      await occurrenceStorage.init();

      final completion = TaskOccurrenceCompletion(
        taskId: taskId,
        occurrenceDate: today,
        completedAt: now,
      );
      await occurrenceStorage.saveCompletion(completion);
    }

    // Cancel remaining active notification for this task slot if needed
    final notifs = FlutterLocalNotificationsPlugin();
    await notifs.cancel(_computeNotificationId(taskId, 0));
    await notifs.cancel(_computeNotificationId(taskId, 8)); // late slot
    await notifs.cancel(_computeNotificationId(taskId, 9)); // immediate slot

    // If taskProvider is available (even in foreground transition), refresh
    if (currentTaskProvider != null) {
      await currentTaskProvider.loadStoredTasks();
    }
  }

  static Future<void> _handleHabitMarkDone(
    String payload, {
    required bool isBackground,
  }) async {
    // Payload can be habit:habitId or habit_late:habitId
    var habitId = payload;
    if (habitId.startsWith('habit:')) {
      habitId = habitId.substring(6);
    } else if (habitId.startsWith('habit_late:')) {
      habitId = habitId.substring(11);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If app is live in foreground and HabitProvider is attached, use it directly
    final currentHabitProvider = habitProvider;
    if (!isBackground && currentHabitProvider != null) {
      final habit = currentHabitProvider.getHabitById(habitId);
      if (habit != null) {
        final target = habit.targetValueForDate(today) ?? habit.targetValue;
        await currentHabitProvider.setProgress(
          habitId,
          today,
          target,
          updatedAt: now,
        );
        return;
      }
    }

    // Background or fallback to Hive storage
    await Hive.initFlutter();

    final habitStorage = HabitStorageService();
    await habitStorage.init();

    final habits = habitStorage.loadHabits();
    final habit = habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) {
      debugPrint('Habit not found in storage: $habitId');
      return;
    }

    final target = habit.targetValueForDate(today) ?? habit.targetValue;
    final progress = HabitProgress(
      habitId: habitId,
      date: today,
      value: target,
      updatedAt: now,
    );
    await habitStorage.saveProgress(progress);

    // Cancel notification for today if desired
    final notifs = FlutterLocalNotificationsPlugin();
    await notifs.cancel(_computeHabitNotificationId(habitId, now.weekday));
    await notifs.cancel(_computeHabitLateNotificationId(habitId, now.weekday));

    if (currentHabitProvider != null) {
      await currentHabitProvider.loadStoredHabits();
    }
  }

  static int _computeNotificationId(String taskId, int slot) {
    var hash = 2166136261;
    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return ((hash % 100000000) * 10 + slot) & 0x7fffffff;
  }

  static int _computeHabitNotificationId(String habitId, int weekday) {
    var hash = 2166136261;
    for (final unit in habitId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 1100000000 + ((hash % 100000000) * 7) + weekday;
  }

  static int _computeHabitLateNotificationId(String habitId, int weekday) {
    var hash = 2166136261;
    for (final unit in habitId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 1200000000 + ((hash % 100000000) * 7) + weekday;
  }
}


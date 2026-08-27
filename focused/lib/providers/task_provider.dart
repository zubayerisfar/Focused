import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_recurrence.dart';
import '../models/task_reminder_result.dart';
import '../services/task_notification_service.dart';
import '../services/task_schedule_service.dart';
import '../services/task_storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskScheduleService _scheduleService = const TaskScheduleService();
  final TaskNotificationService? _notificationService;
  final TaskStorageService? _storageService;
  final List<Task> _tasks = [];

  TaskReminderScheduleResult? _lastReminderResult;
  final Random _random = Random.secure();

  TaskProvider({
    TaskStorageService? storageService,
    TaskNotificationService? notificationService,
  })  : _storageService = storageService,
        _notificationService = notificationService;

  List<Task> get tasks => List.unmodifiable(_tasks);

  List<Task> get incompleteTasks =>
      List.unmodifiable(_tasks.where((task) => !task.isCompleted));

  List<Task> get completedTasks =>
      List.unmodifiable(_tasks.where((task) => task.isCompleted));

  TaskReminderScheduleResult? get lastReminderResult => _lastReminderResult;

  Task? getTaskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }

    return null;
  }

  Future<Task> createTask({
    required String title,
    String description = '',
    required TaskPriority priority,
    required int estimatedMinutes,
    DateTime? plannedDate,
    DateTime? deadline,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    TaskRecurrence recurrence = TaskRecurrence.none,
    Set<int> customWeekdays = const {},
    int? reminderMinutesBefore,
    DateTime? createdAt,
  }) async {
    final creationTime = createdAt ?? DateTime.now();

    final task = Task(
      id: _generateId(creationTime),
      title: title,
      description: description,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recurrence: recurrence,
      customWeekdays: Set<int>.from(customWeekdays),
      reminderMinutesBefore: reminderMinutesBefore,
      createdAt: creationTime,
    );

    await addTask(task);
    return task;
  }

  Future<void> loadStoredTasks() async {
    final storage = _storageService;

    if (storage == null) {
      return;
    }

    final storedTasks = storage.loadTasks();

    _tasks
      ..clear()
      ..addAll(storedTasks);

    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    final duplicate = _tasks.any((existing) => existing.id == task.id);

    if (duplicate) {
      throw StateError('A task with ID ${task.id} already exists.');
    }

    _tasks.add(task);
    notifyListeners();

    try {
      await _storageService?.saveTask(task);
    } catch (_) {
      _tasks.removeWhere((existing) => existing.id == task.id);
      notifyListeners();
      rethrow;
    }

    await _scheduleReminderSafely(task);
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);

    if (index == -1) {
      throw StateError('Cannot update a task that does not exist.');
    }

    final previousTask = _tasks[index];
    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _storageService?.saveTask(updatedTask);
    } catch (_) {
      _tasks[index] = previousTask;
      notifyListeners();
      rethrow;
    }

    await _scheduleReminderSafely(updatedTask);
  }

  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);

    if (index == -1) {
      return;
    }

    final removedTask = _tasks.removeAt(index);
    notifyListeners();

    try {
      await _storageService?.deleteTask(id);
    } catch (_) {
      _tasks.insert(index, removedTask);
      notifyListeners();
      rethrow;
    }

    await _cancelReminderSafely(id);
  }

  Future<void> setCompleted(
    String id,
    bool completed, {
    DateTime? time,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);

    if (index == -1) {
      throw StateError('Cannot complete a task that does not exist.');
    }

    final previousTask = _tasks[index];

    if (previousTask.isCompleted == completed) {
      return;
    }

    final updatedTask = completed
        ? previousTask.markCompleted(time ?? DateTime.now())
        : previousTask.markIncomplete();

    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _storageService?.saveTask(updatedTask);
    } catch (_) {
      _tasks[index] = previousTask;
      notifyListeners();
      rethrow;
    }

    if (updatedTask.isCompleted) {
      await _cancelReminderSafely(updatedTask.id);
    } else {
      await _scheduleReminderSafely(updatedTask);
    }
  }

  List<TaskOccurrence> scheduledOccurrencesForDate(DateTime date) {
    final result = <TaskOccurrence>[];

    for (final task in _tasks) {
      if (task.isCompleted) {
        continue;
      }

      final occurrence = _scheduleService.occurrenceForDate(task, date);
      if (occurrence != null) {
        result.add(occurrence);
      }
    }

    result.sort((first, second) => first.start.compareTo(second.start));
    return List.unmodifiable(result);
  }

  List<Task> tasksForDate(
    DateTime date, {
    bool includeCompleted = true,
  }) {
    final result = _tasks.where((task) {
      if (!includeCompleted && task.isCompleted) {
        return false;
      }

      if (task.recurrence != TaskRecurrence.none &&
          _scheduleService.occursOnDate(task, date)) {
        return true;
      }

      if (task.scheduledStart != null && _sameDate(task.scheduledStart!, date)) {
        return true;
      }

      if (task.plannedDate != null && _sameDate(task.plannedDate!, date)) {
        return true;
      }

      return false;
    }).toList();

    result.sort(_compareTasks);
    return List.unmodifiable(result);
  }

  Map<TaskPriority, List<Task>> tasksByPriorityForDate(
    DateTime date, {
    bool includeCompleted = false,
  }) {
    final dateTasks = tasksForDate(
      date,
      includeCompleted: includeCompleted,
    );

    return {
      for (final priority in TaskPriority.values)
        priority: List.unmodifiable(
          dateTasks.where((task) => task.priority == priority),
        ),
    };
  }

  Task? nextTask({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final incomplete = _tasks.where((task) => !task.isCompleted).toList();

    if (incomplete.isEmpty) {
      return null;
    }

    final activeScheduled = incomplete.where((task) {
      final occurrence = _scheduleService.occurrenceForDate(task, currentTime);

      if (occurrence == null) {
        return false;
      }

      return !currentTime.isBefore(occurrence.start) &&
          currentTime.isBefore(occurrence.end);
    }).toList();

    if (activeScheduled.isNotEmpty) {
      activeScheduled.sort((a, b) {
        final aStart = _scheduleService
            .occurrenceForDate(a, currentTime)!
            .start;
        final bStart = _scheduleService
            .occurrenceForDate(b, currentTime)!
            .start;
        final byTime = aStart.compareTo(bStart);
        return byTime != 0 ? byTime : _compareTasks(a, b);
      });
      return activeScheduled.first;
    }

    final overdue = incomplete.where((task) {
      if (task.recurrence != TaskRecurrence.none) {
        return false;
      }

      if (task.deadline != null && task.deadline!.isBefore(currentTime)) {
        return true;
      }

      if (task.plannedDate != null &&
          _dateOnly(task.plannedDate!).isBefore(_dateOnly(currentTime))) {
        return true;
      }

      return false;
    }).toList();

    if (overdue.isNotEmpty) {
      overdue.sort(_compareTasks);
      return overdue.first;
    }

    final upcomingToday = incomplete.where((task) {
      final occurrence = _scheduleService.occurrenceForDate(task, currentTime);
      return occurrence != null && occurrence.start.isAfter(currentTime);
    }).toList();

    upcomingToday.sort((a, b) {
      final aStart = _scheduleService.occurrenceForDate(a, currentTime)!.start;
      final bStart = _scheduleService.occurrenceForDate(b, currentTime)!.start;
      final byTime = aStart.compareTo(bStart);
      return byTime != 0 ? byTime : _compareTasks(a, b);
    });

    if (upcomingToday.isNotEmpty) {
      return upcomingToday.first;
    }

    final plannedToday = incomplete.where((task) {
      return task.scheduledStart == null &&
          task.plannedDate != null &&
          _sameDate(task.plannedDate!, currentTime);
    }).toList();

    plannedToday.sort(_compareTasks);

    if (plannedToday.isNotEmpty) {
      return plannedToday.first;
    }

    incomplete.sort(_compareTasks);
    return incomplete.first;
  }

  List<Task> plannerToday({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    final result = _tasks.where((task) {
      if (task.isCompleted) {
        return false;
      }
      return _belongsToToday(task, currentTime);
    }).toList();

    result.sort((a, b) => _comparePlannerToday(a, b, currentTime));
    return List.unmodifiable(result);
  }

  List<Task> plannerUpcoming({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    final result = _tasks.where((task) {
      if (task.isCompleted || _belongsToToday(task, currentTime)) {
        return false;
      }

      return _nextFutureDate(task, currentTime) != null;
    }).toList();

    result.sort((a, b) {
      final firstDate = _nextFutureDate(a, currentTime);
      final secondDate = _nextFutureDate(b, currentTime);

      if (firstDate != null && secondDate != null) {
        final dateComparison = firstDate.compareTo(secondDate);
        if (dateComparison != 0) {
          return dateComparison;
        }
      }

      return _compareTasks(a, b);
    });

    return List.unmodifiable(result);
  }

  List<Task> plannerBacklog({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    final result = _tasks.where((task) {
      if (task.isCompleted || _belongsToToday(task, currentTime)) {
        return false;
      }

      return _nextFutureDate(task, currentTime) == null;
    }).toList();

    result.sort(_compareTasks);
    return List.unmodifiable(result);
  }

  List<Task> plannerCompleted() {
    final result = _tasks.where((task) => task.isCompleted).toList();

    result.sort((a, b) {
      final first = a.completedAt ?? a.createdAt;
      final second = b.completedAt ?? b.createdAt;
      return second.compareTo(first);
    });

    return List.unmodifiable(result);
  }

  bool _belongsToToday(Task task, DateTime currentTime) {
    if (task.isCompleted) {
      return false;
    }

    if (task.recurrence != TaskRecurrence.none &&
        _scheduleService.occursOnDate(task, currentTime)) {
      return true;
    }

    if (_isActiveScheduledTask(task, currentTime)) {
      return true;
    }

    if (_isOverdue(task, currentTime)) {
      return true;
    }

    if (task.scheduledStart != null &&
        _sameDate(task.scheduledStart!, currentTime)) {
      return true;
    }

    if (task.plannedDate != null && _sameDate(task.plannedDate!, currentTime)) {
      return true;
    }

    if (task.deadline != null && _sameDate(task.deadline!, currentTime)) {
      return true;
    }

    return false;
  }

  bool _isActiveScheduledTask(Task task, DateTime now) {
    final occurrence = _scheduleService.occurrenceForDate(task, now);

    if (occurrence == null) {
      return false;
    }

    return !now.isBefore(occurrence.start) && now.isBefore(occurrence.end);
  }

  bool _isOverdue(Task task, DateTime currentTime) {
    if (task.isCompleted || task.recurrence != TaskRecurrence.none) {
      return false;
    }

    if (_isActiveScheduledTask(task, currentTime)) {
      return false;
    }

    if (task.scheduledEnd != null && task.scheduledEnd!.isBefore(currentTime)) {
      return true;
    }

    if (task.deadline != null && task.deadline!.isBefore(currentTime)) {
      return true;
    }

    if (task.plannedDate != null &&
        _dateOnly(task.plannedDate!).isBefore(_dateOnly(currentTime))) {
      return true;
    }

    return false;
  }

  DateTime? _nextFutureDate(Task task, DateTime currentTime) {
    if (task.recurrence != TaskRecurrence.none) {
      return _scheduleService.nextOccurrenceStart(task, currentTime);
    }

    final today = _dateOnly(currentTime);
    final candidates = <DateTime>[];

    if (task.scheduledStart != null && task.scheduledStart!.isAfter(currentTime)) {
      candidates.add(task.scheduledStart!);
    }

    if (task.plannedDate != null) {
      final plannedDay = _dateOnly(task.plannedDate!);
      if (plannedDay.isAfter(today)) {
        candidates.add(plannedDay);
      }
    }

    if (task.deadline != null &&
        task.deadline!.isAfter(currentTime) &&
        !_sameDate(task.deadline!, currentTime)) {
      candidates.add(task.deadline!);
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort();
    return candidates.first;
  }

  int _comparePlannerToday(Task first, Task second, DateTime now) {
    final firstRank = _todayTaskRank(first, now);
    final secondRank = _todayTaskRank(second, now);
    final rankComparison = firstRank.compareTo(secondRank);

    if (rankComparison != 0) {
      return rankComparison;
    }

    final firstOccurrence = _scheduleService.occurrenceForDate(first, now);
    final secondOccurrence = _scheduleService.occurrenceForDate(second, now);

    if (firstOccurrence != null && secondOccurrence != null) {
      final byTime = firstOccurrence.start.compareTo(secondOccurrence.start);
      if (byTime != 0) {
        return byTime;
      }
    }

    return _compareTasks(first, second);
  }

  int _todayTaskRank(Task task, DateTime now) {
    if (_isActiveScheduledTask(task, now)) {
      return 0;
    }

    if (_isOverdue(task, now)) {
      return 1;
    }

    if (_scheduleService.occurrenceForDate(task, now) != null) {
      return 2;
    }

    return 3;
  }

  int _compareTasks(Task first, Task second) {
    final priorityComparison =
        first.priority.sortOrder.compareTo(second.priority.sortOrder);

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    if (first.scheduledStart != null && second.scheduledStart != null) {
      final scheduleComparison =
          first.scheduledStart!.compareTo(second.scheduledStart!);
      if (scheduleComparison != 0) {
        return scheduleComparison;
      }
    }

    if (first.deadline != null && second.deadline != null) {
      final deadlineComparison = first.deadline!.compareTo(second.deadline!);
      if (deadlineComparison != 0) {
        return deadlineComparison;
      }
    }

    return first.createdAt.compareTo(second.createdAt);
  }

  Future<void> _scheduleReminderSafely(Task task) async {
    final service = _notificationService;

    if (service == null) {
      _lastReminderResult = null;
      return;
    }

    try {
      _lastReminderResult = await service.scheduleForTask(task);
    } catch (error, stackTrace) {
      _lastReminderResult = TaskReminderScheduleResult.error(
        taskId: task.id,
        message: 'Reminder scheduling failed: $error',
      );

      debugPrint('Could not schedule reminder for ${task.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> sendTestNotification() async {
    final service = _notificationService;

    if (service == null) {
      return false;
    }

    try {
      return await service.sendTestNotification();
    } catch (error, stackTrace) {
      debugPrint('Could not send test notification: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<int> pendingReminderCount() async {
    final service = _notificationService;

    if (service == null) {
      return 0;
    }

    try {
      return await service.pendingReminderCount();
    } catch (error, stackTrace) {
      debugPrint('Could not read pending reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    }
  }

  Future<void> _cancelReminderSafely(String taskId) async {
    try {
      await _notificationService?.cancelForTask(taskId);
    } catch (error, stackTrace) {
      debugPrint('Could not cancel reminder for $taskId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _generateId(DateTime creationTime) {
    String randomHex() {
      return _random.nextInt(65536).toRadixString(16).padLeft(4, '0');
    }

    return '${creationTime.toUtc().microsecondsSinceEpoch}'
        '-${randomHex()}'
        '-${randomHex()}'
        '-${randomHex()}'
        '-${randomHex()}';
  }
}

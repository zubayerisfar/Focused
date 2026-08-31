import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../models/task_occurrence_completion.dart';
import '../models/task_recurrence.dart';
import '../models/task_reminder_result.dart';
import '../models/task_schedule_conflict.dart';
import '../services/task_conflict_service.dart';
import '../services/task_notification_service.dart';
import '../services/task_occurrence_completion_storage_service.dart';
import '../services/task_schedule_service.dart';
import '../services/task_storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskScheduleService _scheduleService = const TaskScheduleService();
  final TaskConflictService _conflictService = const TaskConflictService();
  final TaskNotificationService? _notificationService;
  final TaskStorageService? _storageService;
  final TaskOccurrenceCompletionStorageService? _occurrenceCompletionStorage;
  final List<Task> _tasks = [];
  final List<TaskOccurrenceCompletion> _occurrenceCompletions = [];

  TaskReminderScheduleResult? _lastReminderResult;
  final Random _random = Random.secure();

  TaskProvider({
    TaskStorageService? storageService,
    TaskNotificationService? notificationService,
    TaskOccurrenceCompletionStorageService? occurrenceCompletionStorage,
  })  : _storageService = storageService,
        _notificationService = notificationService,
        _occurrenceCompletionStorage = occurrenceCompletionStorage;

  List<Task> get tasks => List.unmodifiable(_tasks);

  List<TaskOccurrenceCompletion> get occurrenceCompletions =>
      List.unmodifiable(_occurrenceCompletions);

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

    if (storage != null) {
      final storedTasks = storage.loadTasks();

      _tasks
        ..clear()
        ..addAll(storedTasks);
    }

    final completionStorage = _occurrenceCompletionStorage;

    if (completionStorage != null) {
      final tasksById = {
        for (final task in _tasks) task.id: task,
      };
      final validCompletions = <TaskOccurrenceCompletion>[];

      for (final completion in completionStorage.loadCompletions()) {
        final task = tasksById[completion.taskId];

        if (task != null &&
            task.recurrence != TaskRecurrence.none) {
          validCompletions.add(completion);
          continue;
        }

        await completionStorage.deleteCompletion(
          taskId: completion.taskId,
          occurrenceDate: completion.occurrenceDate,
        );
      }

      _occurrenceCompletions
        ..clear()
        ..addAll(validCompletions);
    }

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
    final previousCompletions = _occurrenceCompletions
        .where((completion) => completion.taskId == updatedTask.id)
        .toList();

    _tasks[index] = updatedTask;
    notifyListeners();

    try {
      await _storageService?.saveTask(updatedTask);

      if (previousTask.recurrence != TaskRecurrence.none &&
          updatedTask.recurrence == TaskRecurrence.none) {
        await _occurrenceCompletionStorage?.deleteForTask(
          updatedTask.id,
        );
        _occurrenceCompletions.removeWhere(
          (completion) => completion.taskId == updatedTask.id,
        );
        notifyListeners();
      }
    } catch (_) {
      _tasks[index] = previousTask;

      _occurrenceCompletions.removeWhere(
        (completion) => completion.taskId == updatedTask.id,
      );
      _occurrenceCompletions.addAll(previousCompletions);
      notifyListeners();

      try {
        await _storageService?.saveTask(previousTask);
        for (final completion in previousCompletions) {
          await _occurrenceCompletionStorage?.saveCompletion(
            completion,
          );
        }
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint(
          'Could not fully roll back task update: $rollbackError',
        );
        debugPrintStack(stackTrace: rollbackStackTrace);
      }

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
    final removedCompletions = _occurrenceCompletions
        .where((completion) => completion.taskId == id)
        .toList();

    _occurrenceCompletions.removeWhere(
      (completion) => completion.taskId == id,
    );
    notifyListeners();

    try {
      await _storageService?.deleteTask(id);
      await _occurrenceCompletionStorage?.deleteForTask(id);
    } catch (_) {
      _tasks.insert(index, removedTask);
      _occurrenceCompletions.addAll(removedCompletions);
      notifyListeners();

      try {
        await _storageService?.saveTask(removedTask);
        for (final completion in removedCompletions) {
          await _occurrenceCompletionStorage?.saveCompletion(completion);
        }
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint('Could not fully roll back task deletion: $rollbackError');
        debugPrintStack(stackTrace: rollbackStackTrace);
      }

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

    if (previousTask.recurrence != TaskRecurrence.none) {
      throw StateError(
        'Recurring tasks must be completed per occurrence. '
        'Use setCompletedForDate instead.',
      );
    }

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


  Future<void> setCompletedForDate(
    String taskId,
    DateTime occurrenceDate,
    bool completed, {
    DateTime? completedAt,
  }) async {
    final task = getTaskById(taskId);

    if (task == null) {
      throw StateError('Cannot complete a task that does not exist.');
    }

    if (task.recurrence == TaskRecurrence.none) {
      await setCompleted(
        taskId,
        completed,
        time: completedAt,
      );
      return;
    }

    final day = _dateOnlyLocal(occurrenceDate);

    if (!_scheduleService.occursOnDate(task, day)) {
      throw StateError(
        'The recurring task does not have an occurrence on this date.',
      );
    }

    if (completed) {
      await _completeOccurrence(
        task,
        day,
        completedAt ?? DateTime.now(),
      );
    } else {
      await _uncompleteOccurrence(
        task,
        day,
      );
    }
  }

  bool isOccurrenceCompleted(
    String taskId,
    DateTime occurrenceDate,
  ) {
    return occurrenceCompletionFor(
          taskId,
          occurrenceDate,
        ) !=
        null;
  }

  TaskOccurrenceCompletion? occurrenceCompletionFor(
    String taskId,
    DateTime occurrenceDate,
  ) {
    final day = _dateOnlyLocal(occurrenceDate);

    for (final completion in _occurrenceCompletions) {
      if (completion.taskId == taskId &&
          _sameDate(completion.occurrenceDate, day)) {
        return completion;
      }
    }

    return null;
  }

  bool isTaskCompletedForDate(
    Task task,
    DateTime date,
  ) {
    if (task.recurrence == TaskRecurrence.none) {
      return task.isCompleted;
    }

    if (!_scheduleService.occursOnDate(task, date)) {
      return false;
    }

    return isOccurrenceCompleted(task.id, date);
  }

  DateTime? completedAtForDate(
    Task task,
    DateTime date,
  ) {
    if (task.recurrence == TaskRecurrence.none) {
      return task.completedAt;
    }

    return occurrenceCompletionFor(
      task.id,
      date,
    )?.completedAt;
  }

  /// Number of tasks that belong to the selected date.
  ///
  /// A recurring master contributes at most one occurrence for the day.
  int taskCountForDate(DateTime date) {
    return tasksForDate(
      date,
      includeCompleted: true,
    ).length;
  }

  int completedTaskCountForDate(DateTime date) {
    final dateTasks = tasksForDate(
      date,
      includeCompleted: true,
    );

    return dateTasks.where((task) {
      return isTaskCompletedForDate(task, date);
    }).length;
  }

  int remainingTaskCountForDate(DateTime date) {
    final total = taskCountForDate(date);
    final completed = completedTaskCountForDate(date);
    return total - completed;
  }

  /// Local calendar dates on which the user actually completed task work.
  ///
  /// This intentionally uses completedAt rather than the planned occurrence
  /// date. A late completion therefore contributes to the day on which the
  /// user actually performed the completion action.
  Set<DateTime> completionActivityDates() {
    final result = <DateTime>{};

    for (final task in _tasks) {
      final completedAt = task.completedAt;
      if (task.isCompleted && completedAt != null) {
        result.add(_dateOnlyLocal(completedAt));
      }
    }

    for (final completion in _occurrenceCompletions) {
      result.add(_dateOnlyLocal(completion.completedAt));
    }

    return Set<DateTime>.unmodifiable(result);
  }

  DateTime? nextOccurrenceStartForTask(
    Task task,
    DateTime after,
  ) {
    return _scheduleService.nextOccurrenceStart(
      task,
      after,
    );
  }

  TaskOccurrence? occurrenceForTaskOnDate(
    Task task,
    DateTime date,
  ) {
    final occurrence = _scheduleService.occurrenceForDate(task, date);
    if (occurrence == null) return null;

    return occurrence.withCompletion(
      isCompleted: isTaskCompletedForDate(task, occurrence.start),
      completedAt: completedAtForDate(task, occurrence.start),
    );
  }

  List<TaskOccurrence> scheduledOccurrencesBetween(
    DateTime startDay,
    DateTime endDayExclusive, {
    bool includeCompleted = true,
  }) {
    final start = _dateOnlyLocal(startDay);
    final end = _dateOnlyLocal(endDayExclusive);
    if (!end.isAfter(start)) return const [];

    final result = <TaskOccurrence>[];
    var day = start;
    while (day.isBefore(end)) {
      result.addAll(
        scheduledOccurrencesForDate(
          day,
          includeCompleted: includeCompleted,
        ),
      );
      day = DateTime(day.year, day.month, day.day + 1);
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return List<TaskOccurrence>.unmodifiable(result);
  }

  List<TaskOccurrence> completedRecurringOccurrences() {
    final result = <TaskOccurrence>[];

    for (final completion in _occurrenceCompletions) {
      final task = getTaskById(completion.taskId);

      if (task == null ||
          task.recurrence == TaskRecurrence.none) {
        continue;
      }

      final occurrence = _occurrenceFromCompletion(
        task,
        completion,
      );

      if (occurrence != null) {
        result.add(occurrence);
      }
    }

    result.sort((first, second) {
      final firstCompleted = first.completedAt ?? first.start;
      final secondCompleted = second.completedAt ?? second.start;
      return secondCompleted.compareTo(firstCompleted);
    });

    return List.unmodifiable(result);
  }

  TaskOccurrence? _occurrenceFromCompletion(
    Task task,
    TaskOccurrenceCompletion completion,
  ) {
    final scheduledStart = task.scheduledStart;
    final scheduledEnd = task.scheduledEnd;

    if (scheduledStart == null || scheduledEnd == null) {
      return null;
    }

    final day = _dateOnlyLocal(
      completion.occurrenceDate,
    );
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      scheduledStart.hour,
      scheduledStart.minute,
      scheduledStart.second,
      scheduledStart.millisecond,
      scheduledStart.microsecond,
    );

    return TaskOccurrence(
      task: task,
      start: start,
      end: start.add(
        scheduledEnd.difference(scheduledStart),
      ),
      isCompleted: true,
      completedAt: completion.completedAt,
    );
  }

  Future<void> _completeOccurrence(
    Task task,
    DateTime occurrenceDate,
    DateTime completedAt,
  ) async {
    final existing = occurrenceCompletionFor(
      task.id,
      occurrenceDate,
    );

    if (existing != null) {
      return;
    }

    final completion = TaskOccurrenceCompletion(
      taskId: task.id,
      occurrenceDate: occurrenceDate,
      completedAt: completedAt,
    );

    _occurrenceCompletions.add(completion);
    notifyListeners();

    try {
      await _occurrenceCompletionStorage?.saveCompletion(
        completion,
      );
    } catch (_) {
      _occurrenceCompletions.removeWhere(
        (item) => item.storageKey == completion.storageKey,
      );
      notifyListeners();
      rethrow;
    }

    await _rescheduleReminderAfterOccurrenceCompletion(
      task,
      occurrenceDate,
    );
  }

  Future<void> _uncompleteOccurrence(
    Task task,
    DateTime occurrenceDate,
  ) async {
    final existing = occurrenceCompletionFor(
      task.id,
      occurrenceDate,
    );

    if (existing == null) {
      return;
    }

    _occurrenceCompletions.removeWhere(
      (item) => item.storageKey == existing.storageKey,
    );
    notifyListeners();

    try {
      await _occurrenceCompletionStorage?.deleteCompletion(
        taskId: task.id,
        occurrenceDate: occurrenceDate,
      );
    } catch (_) {
      _occurrenceCompletions.add(existing);
      notifyListeners();
      rethrow;
    }

    if (_sameDate(
      _dateOnlyLocal(occurrenceDate),
      _dateOnlyLocal(DateTime.now()),
    )) {
      await _scheduleReminderSafely(task);
    }
  }

  Future<void> _rescheduleReminderAfterOccurrenceCompletion(
    Task task,
    DateTime occurrenceDate,
  ) async {
    if (_notificationService == null ||
        task.reminderMinutesBefore == null ||
        !_sameDate(
          _dateOnlyLocal(occurrenceDate),
          _dateOnlyLocal(DateTime.now()),
        )) {
      return;
    }

    final occurrence = _scheduleService.occurrenceForDate(
      task,
      occurrenceDate,
    );

    if (occurrence == null) {
      return;
    }

    final nextStart = _scheduleService.nextOccurrenceStart(
      task,
      occurrence.end,
    );

    if (nextStart == null) {
      await _cancelReminderSafely(task.id);
      return;
    }

    final notificationTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      plannedDate: task.plannedDate,
      deadline: task.deadline,
      scheduledStart: nextStart,
      scheduledEnd: nextStart.add(occurrence.duration),
      recurrence: task.recurrence,
      customWeekdays: Set<int>.from(task.customWeekdays),
      reminderMinutesBefore: task.reminderMinutesBefore,
      createdAt: task.createdAt,
    );

    await _scheduleReminderSafely(notificationTask);
  }

  List<TaskScheduleConflict> findScheduleConflicts({
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    TaskRecurrence recurrence = TaskRecurrence.none,
    Set<int> customWeekdays = const {},
    String? ignoreTaskId,
  }) {
    return _conflictService.findConflicts(
      candidateStart: scheduledStart,
      candidateEnd: scheduledEnd,
      recurrence: recurrence,
      customWeekdays: Set<int>.from(customWeekdays),
      existingTasks: _tasks,
      ignoreTaskId: ignoreTaskId,
    );
  }

  List<TaskOccurrence> scheduledOccurrencesForDate(
    DateTime date, {
    bool includeCompleted = true,
  }) {
    final result = <TaskOccurrence>[];

    for (final task in _tasks) {
      final occurrence = _scheduleService.occurrenceForDate(
        task,
        date,
      );

      if (occurrence != null) {
        final isCompleted = isTaskCompletedForDate(
          task,
          occurrence.start,
        );

        if (!includeCompleted && isCompleted) {
          continue;
        }

        result.add(
          occurrence.withCompletion(
            isCompleted: isCompleted,
            completedAt: completedAtForDate(
              task,
              occurrence.start,
            ),
          ),
        );
        continue;
      }

      if (!includeCompleted ||
          task.recurrence == TaskRecurrence.none) {
        continue;
      }

      final historicalCompletion = occurrenceCompletionFor(
        task.id,
        date,
      );

      if (historicalCompletion == null) {
        continue;
      }

      final historicalOccurrence = _occurrenceFromCompletion(
        task,
        historicalCompletion,
      );

      if (historicalOccurrence != null) {
        result.add(historicalOccurrence);
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
      if (!includeCompleted &&
          isTaskCompletedForDate(task, date)) {
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

      if (occurrence == null ||
          isTaskCompletedForDate(task, occurrence.start)) {
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

      return occurrence != null &&
          !isTaskCompletedForDate(task, occurrence.start) &&
          occurrence.start.isAfter(currentTime);
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

    final fallback = incomplete.where((task) {
      if (task.recurrence == TaskRecurrence.none) {
        return true;
      }

      if (!_scheduleService.occursOnDate(task, currentTime)) {
        return true;
      }

      return !isOccurrenceCompleted(task.id, currentTime);
    }).toList();

    if (fallback.isEmpty) {
      return null;
    }

    fallback.sort(_compareTasks);
    return fallback.first;
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

    if (occurrence == null ||
        isTaskCompletedForDate(task, occurrence.start)) {
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
    if (task.recurrence != TaskRecurrence.none &&
        _scheduleService.occursOnDate(task, now) &&
        isOccurrenceCompleted(task.id, now)) {
      return 4;
    }

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


  Future<bool> requestNotificationPermission() async {
    final service = _notificationService;
    if (service == null) return false;
    try {
      return await service.requestNotificationPermission();
    } catch (error, stackTrace) {
      debugPrint('Could not request notification permission: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool?> notificationsEnabled() async {
    final service = _notificationService;
    if (service == null) return null;
    try {
      return await service.notificationsEnabled();
    } catch (error, stackTrace) {
      debugPrint('Could not read notification permission: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
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

  DateTime _dateOnlyLocal(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateTime(local.year, local.month, local.day);
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

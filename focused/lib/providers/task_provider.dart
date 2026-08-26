import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/task.dart';

import '../services/task_storage_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskStorageService? _storageService;

  TaskProvider({TaskStorageService? storageService})
    : _storageService = storageService;
  final List<Task> _tasks = [];

  final Random _random = Random.secure();

  List<Task> get tasks {
    return List.unmodifiable(_tasks);
  }

  List<Task> get incompleteTasks {
    return List.unmodifiable(_tasks.where((task) => !task.isCompleted));
  }

  List<Task> get completedTasks {
    return List.unmodifiable(_tasks.where((task) => task.isCompleted));
  }

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
      // Roll back memory if persistence fails.
      _tasks.removeWhere((existing) => existing.id == task.id);

      notifyListeners();

      rethrow;
    }
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
  }

  Future<void> setCompleted(String id, bool completed, {DateTime? time}) async {
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
  }

  List<Task> tasksForDate(DateTime date, {bool includeCompleted = true}) {
    final result = _tasks.where((task) {
      if (!includeCompleted && task.isCompleted) {
        return false;
      }

      if (task.scheduledStart != null &&
          _sameDate(task.scheduledStart!, date)) {
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
    final tasks = tasksForDate(date, includeCompleted: includeCompleted);

    return {
      for (final priority in TaskPriority.values)
        priority: List.unmodifiable(
          tasks.where((task) => task.priority == priority),
        ),
    };
  }

  /// Finds the most useful task to surface on the Today screen.
  Task? nextTask({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    final incomplete = _tasks.where((task) => !task.isCompleted).toList();

    if (incomplete.isEmpty) {
      return null;
    }

    // 1. A scheduled task happening right now.
    final activeScheduled = incomplete.where((task) {
      final start = task.scheduledStart;
      final end = task.scheduledEnd;

      if (start == null || end == null) {
        return false;
      }

      return !currentTime.isBefore(start) && currentTime.isBefore(end);
    }).toList();

    if (activeScheduled.isNotEmpty) {
      activeScheduled.sort(_compareTasks);
      return activeScheduled.first;
    }

    // 2. Overdue unfinished work.
    final overdue = incomplete.where((task) {
      if (task.deadline != null && task.deadline!.isBefore(currentTime)) {
        return true;
      }

      if (task.plannedDate != null) {
        final plannedDay = _dateOnly(task.plannedDate!);
        final today = _dateOnly(currentTime);

        if (plannedDay.isBefore(today)) {
          return true;
        }
      }

      return false;
    }).toList();

    if (overdue.isNotEmpty) {
      overdue.sort(_compareTasks);
      return overdue.first;
    }

    // 3. Next scheduled task today.
    final upcomingToday = incomplete.where((task) {
      final start = task.scheduledStart;

      if (start == null) {
        return false;
      }

      return _sameDate(start, currentTime) && start.isAfter(currentTime);
    }).toList();

    upcomingToday.sort((a, b) {
      final byTime = a.scheduledStart!.compareTo(b.scheduledStart!);

      if (byTime != 0) {
        return byTime;
      }

      return _compareTasks(a, b);
    });

    if (upcomingToday.isNotEmpty) {
      return upcomingToday.first;
    }

    // 4. Unscheduled tasks planned for today.
    final plannedToday = incomplete.where((task) {
      return task.plannedDate != null &&
          _sameDate(task.plannedDate!, currentTime);
    }).toList();

    plannedToday.sort(_compareTasks);

    if (plannedToday.isNotEmpty) {
      return plannedToday.first;
    }

    // 5. Otherwise surface the highest-priority backlog task.
    incomplete.sort(_compareTasks);

    return incomplete.first;
  }

  int _compareTasks(Task first, Task second) {
    final priorityComparison = first.priority.sortOrder.compareTo(
      second.priority.sortOrder,
    );

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    if (first.scheduledStart != null && second.scheduledStart != null) {
      final scheduleComparison = first.scheduledStart!.compareTo(
        second.scheduledStart!,
      );

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

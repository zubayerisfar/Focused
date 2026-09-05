import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/tasks/models/task.dart';
import 'package:focused/features/tasks/models/task_occurrence_completion.dart';
import 'package:focused/features/tasks/models/task_recurrence.dart';
import 'package:focused/features/tasks/providers/task_provider.dart';
import 'package:focused/features/tasks/services/task_occurrence_completion_storage_service.dart';
import 'package:focused/features/tasks/services/task_storage_service.dart';

class InMemoryTaskStorageService implements TaskStorageService {
  final Map<String, Task> _store = {};

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}

  @override
  List<Task> loadTasks() => _store.values.toList();

  @override
  Task? loadTask(String taskId) => _store[taskId];

  @override
  Future<void> saveTask(Task task) async {
    _store[task.id] = task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _store.remove(taskId);
  }

  @override
  Future<void> clearAllTasks() async {
    _store.clear();
  }
}

class InMemoryOccurrenceCompletionStorageService
    implements TaskOccurrenceCompletionStorageService {
  final Map<String, TaskOccurrenceCompletion> _store = {};

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}

  @override
  List<TaskOccurrenceCompletion> loadCompletions() => _store.values.toList();

  @override
  Future<void> saveCompletion(TaskOccurrenceCompletion completion) async {
    _store[completion.storageKey] = completion;
  }

  @override
  Future<void> deleteCompletion({
    required String taskId,
    required DateTime occurrenceDate,
  }) async {
    _store.remove(
      TaskOccurrenceCompletion.buildStorageKey(taskId, occurrenceDate),
    );
  }

  @override
  Future<void> deleteForTask(String taskId) async {
    _store.removeWhere((key, _) => key.startsWith('$taskId|'));
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

void main() {
  late InMemoryTaskStorageService taskStorage;
  late InMemoryOccurrenceCompletionStorageService completionStorage;
  late TaskProvider taskProvider;

  setUp(() async {
    taskStorage = InMemoryTaskStorageService();
    completionStorage = InMemoryOccurrenceCompletionStorageService();
    taskProvider = TaskProvider(
      storageService: taskStorage,
      occurrenceCompletionStorage: completionStorage,
    );
  });

  test('create and delete non-recurring task', () async {
    final task = await taskProvider.createTask(
      title: 'Finish report',
      priority: TaskPriority.critical,
      plannedDate: DateTime(2026, 9, 2),
    );

    expect(taskProvider.tasks.length, 1);
    expect(taskProvider.getTaskById(task.id), isNotNull);

    await taskProvider.deleteTask(task.id);

    expect(taskProvider.tasks.length, 0);
    expect(taskProvider.getTaskById(task.id), isNull);
    expect(taskStorage.loadTasks().length, 0);
  });

  test('delete recurring task cleans up occurrence completions', () async {
    final task = await taskProvider.createTask(
      title: 'Daily meditation',
      priority: TaskPriority.important,
      recurrence: TaskRecurrence.daily,
      scheduledStart: DateTime(2026, 9, 2, 8),
      scheduledEnd: DateTime(2026, 9, 2, 8, 30),
    );

    final today = DateTime(2026, 9, 2);
    await taskProvider.setCompletedForDate(task.id, today, true);

    expect(taskProvider.isOccurrenceCompleted(task.id, today), isTrue);
    expect(completionStorage.loadCompletions().length, 1);

    await taskProvider.deleteTask(task.id);

    expect(taskProvider.tasks.length, 0);
    expect(taskProvider.occurrenceCompletions.length, 0);
    expect(completionStorage.loadCompletions().length, 0);
  });
}

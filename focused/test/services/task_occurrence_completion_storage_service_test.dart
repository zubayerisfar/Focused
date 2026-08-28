import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_occurrence_completion.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/services/task_occurrence_completion_storage_service.dart';
import 'package:focused/services/task_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused-occurrence-completion-',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('completion survives provider reload', () async {
    final taskStorage = TaskStorageService();
    final completionStorage =
        TaskOccurrenceCompletionStorageService();

    await taskStorage.init();
    await completionStorage.init();

    final firstProvider = TaskProvider(
      storageService: taskStorage,
      occurrenceCompletionStorage: completionStorage,
    );

    final task = Task(
      id: 'daily',
      title: 'Daily',
      priority: TaskPriority.important,
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 20),
      recurrence: TaskRecurrence.daily,
      createdAt: DateTime(2026, 8, 20),
    );

    await firstProvider.addTask(task);
    await firstProvider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
      completedAt: DateTime(2026, 8, 27, 20),
    );

    final secondProvider = TaskProvider(
      storageService: taskStorage,
      occurrenceCompletionStorage: completionStorage,
    );

    await secondProvider.loadStoredTasks();

    expect(
      secondProvider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 27),
      ),
      isTrue,
    );
    expect(
      secondProvider.isOccurrenceCompleted(
        task.id,
        DateTime(2026, 8, 28),
      ),
      isFalse,
    );
  });

  test('deleteForTask removes only selected series history', () async {
    final storage = TaskOccurrenceCompletionStorageService();
    await storage.init();

    final first = TaskOccurrenceCompletion(
      taskId: 'first',
      occurrenceDate: DateTime(2026, 8, 27),
      completedAt: DateTime(2026, 8, 27, 20),
    );
    final second = TaskOccurrenceCompletion(
      taskId: 'second',
      occurrenceDate: DateTime(2026, 8, 27),
      completedAt: DateTime(2026, 8, 27, 21),
    );

    await storage.saveCompletion(first);
    await storage.saveCompletion(second);
    await storage.deleteForTask('first');

    final remaining = storage.loadCompletions();

    expect(remaining, hasLength(1));
    expect(remaining.single.taskId, 'second');
  });

  test('provider series deletion cleans persisted completion history',
      () async {
    final taskStorage = TaskStorageService();
    final completionStorage =
        TaskOccurrenceCompletionStorageService();

    await taskStorage.init();
    await completionStorage.init();

    final provider = TaskProvider(
      storageService: taskStorage,
      occurrenceCompletionStorage: completionStorage,
    );

    final task = Task(
      id: 'weekly',
      title: 'Weekly',
      priority: TaskPriority.growth,
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 20),
      recurrence: TaskRecurrence.weekly,
      createdAt: DateTime(2026, 8, 20),
    );

    await provider.addTask(task);
    await provider.setCompletedForDate(
      task.id,
      DateTime(2026, 8, 27),
      true,
    );

    await provider.deleteTask(task.id);

    expect(completionStorage.loadCompletions(), isEmpty);
    expect(taskStorage.loadTasks(), isEmpty);
  });
}

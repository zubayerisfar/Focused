import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../lib/models/task.dart';
import '../lib/models/task_recurrence.dart';
import '../lib/providers/task_provider.dart';
import '../lib/services/task_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late TaskStorageService storage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused_task_test_',
    );

    Hive.init(tempDirectory.path);

    storage = TaskStorageService();
    await storage.init();
    await storage.clearAllTasks();
  });

  tearDown(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('createTask survives reload from Hive', () async {
    final provider = TaskProvider(storageService: storage);

    final created = await provider.createTask(
      title: 'Code',
      priority: TaskPriority.important,
      estimatedMinutes: 120,
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.daily,
      reminderMinutesBefore: 15,
      createdAt: DateTime(2026, 8, 27, 10),
    );

    final reloaded = TaskProvider(storageService: storage);
    await reloaded.loadStoredTasks();

    final task = reloaded.getTaskById(created.id);

    expect(task, isNotNull);
    expect(task!.title, 'Code');
    expect(task.recurrence, TaskRecurrence.daily);
    expect(task.reminderMinutesBefore, 15);
  });

  test('updateTask survives reload from Hive', () async {
    final provider = TaskProvider(storageService: storage);

    final created = await provider.createTask(
      title: 'Code',
      priority: TaskPriority.important,
      estimatedMinutes: 120,
      createdAt: DateTime(2026, 8, 27, 10),
    );

    await provider.updateTask(
      Task(
        id: created.id,
        title: 'Code deeply',
        priority: TaskPriority.critical,
        estimatedMinutes: 90,
        plannedDate: DateTime(2026, 8, 28),
        createdAt: created.createdAt,
      ),
    );

    final reloaded = TaskProvider(storageService: storage);
    await reloaded.loadStoredTasks();

    final task = reloaded.getTaskById(created.id)!;

    expect(task.title, 'Code deeply');
    expect(task.priority, TaskPriority.critical);
    expect(task.estimatedMinutes, 90);
    expect(task.plannedDate, DateTime(2026, 8, 28));
  });

  test('deleteTask survives reload from Hive', () async {
    final provider = TaskProvider(storageService: storage);

    final created = await provider.createTask(
      title: 'Delete me',
      priority: TaskPriority.growth,
      estimatedMinutes: 30,
      createdAt: DateTime(2026, 8, 27, 10),
    );

    await provider.deleteTask(created.id);

    final reloaded = TaskProvider(storageService: storage);
    await reloaded.loadStoredTasks();

    expect(reloaded.getTaskById(created.id), isNull);
    expect(reloaded.tasks, isEmpty);
  });
}

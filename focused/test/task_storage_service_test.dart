import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_recurrence.dart';
import 'package:focused/services/task_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused-task-storage-',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('save and reload current task schema', () async {
    final storage = TaskStorageService();
    await storage.init();

    final task = Task(
      id: 'persisted',
      title: 'Code',
      description: 'Build feature',
      priority: TaskPriority.critical,
      plannedDate: DateTime(2026, 8, 27),
      scheduledStart: DateTime(2026, 8, 27, 19),
      scheduledEnd: DateTime(2026, 8, 27, 21),
      recurrence: TaskRecurrence.daily,
      reminderMinutesBefore: 15,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    await storage.saveTask(task);

    final loaded = storage.loadTasks();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'persisted');
    expect(loaded.single.scheduledDurationMinutes, 120);
    expect(loaded.single.recurrence, TaskRecurrence.daily);
    expect(loaded.single.reminderMinutesBefore, 15);
  });

  test('stored map uses current schema version', () async {
    final storage = TaskStorageService();
    await storage.init();

    final task = Task(
      id: 'schema',
      title: 'Schema',
      priority: TaskPriority.important,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    await storage.saveTask(task);

    final box = Hive.box<dynamic>('focused_tasks');
    final raw = Map<dynamic, dynamic>.from(
      box.get('schema') as Map,
    );

    expect(raw['schemaVersion'], 3);
  });

  test('delete removes task from storage', () async {
    final storage = TaskStorageService();
    await storage.init();

    final task = Task(
      id: 'delete-me',
      title: 'Delete',
      priority: TaskPriority.important,
      createdAt: DateTime(2026, 8, 27, 12),
    );

    await storage.saveTask(task);
    await storage.deleteTask(task.id);

    expect(storage.loadTasks(), isEmpty);
  });
}

import 'package:hive_ce/hive_ce.dart';

import '../models/task.dart';

class TaskStorageService {
  static const String _boxName = 'focused_tasks';

  Box<dynamic>? _box;

  bool get isInitialized {
    return _box != null && _box!.isOpen;
  }

  Future<void> init() async {
    if (isInitialized) {
      return;
    }

    _box = await Hive.openBox<dynamic>(_boxName);
  }

  List<Task> loadTasks() {
    final box = _requireBox();

    final List<Task> tasks = [];

    for (final value in box.values) {
      if (value is! Map) {
        continue;
      }

      tasks.add(Task.fromMap(Map<dynamic, dynamic>.from(value)));
    }

    return tasks;
  }

  Future<void> saveTask(Task task) async {
    final box = _requireBox();

    await box.put(task.id, task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    final box = _requireBox();

    await box.delete(taskId);
  }

  Future<void> clearAllTasks() async {
    final box = _requireBox();

    await box.clear();
  }

  Box<dynamic> _requireBox() {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError('TaskStorageService has not been initialized.');
    }

    return box;
  }
}

import 'package:hive_ce/hive_ce.dart';

import '../models/task_occurrence_completion.dart';

class TaskOccurrenceCompletionStorageService {
  static const String _boxName = 'focused_task_occurrence_completions';

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

  List<TaskOccurrenceCompletion> loadCompletions() {
    final box = _requireBox();
    final result = <TaskOccurrenceCompletion>[];

    for (final value in box.values) {
      if (value is! Map) {
        continue;
      }

      try {
        result.add(
          TaskOccurrenceCompletion.fromMap(
            Map<dynamic, dynamic>.from(value),
          ),
        );
      } on FormatException {
        // Ignore malformed development/local records instead of crashing
        // the entire app startup.
      } on ArgumentError {
        // Ignore malformed development/local records instead of crashing
        // the entire app startup.
      }
    }

    return result;
  }

  Future<void> saveCompletion(
    TaskOccurrenceCompletion completion,
  ) async {
    final box = _requireBox();

    await box.put(
      completion.storageKey,
      completion.toMap(),
    );
  }

  Future<void> deleteCompletion({
    required String taskId,
    required DateTime occurrenceDate,
  }) async {
    final box = _requireBox();

    await box.delete(
      TaskOccurrenceCompletion.buildStorageKey(
        taskId,
        occurrenceDate,
      ),
    );
  }

  Future<void> deleteForTask(String taskId) async {
    final box = _requireBox();
    final keys = <dynamic>[];

    for (final key in box.keys) {
      if (key is String && key.startsWith('$taskId|')) {
        keys.add(key);
      }
    }

    if (keys.isNotEmpty) {
      await box.deleteAll(keys);
    }
  }

  Future<void> clearAll() async {
    final box = _requireBox();
    await box.clear();
  }

  Box<dynamic> _requireBox() {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError(
        'TaskOccurrenceCompletionStorageService has not been initialized.',
      );
    }

    return box;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/task_provider.dart';

void main() {
  test(
    'focus completion and task completion stay explicit but synchronize once marked done',
    () async {
      var now = DateTime(2026, 8, 28, 22, 50);

      final focusProvider = FocusProvider(now: () => now);
      final taskProvider = TaskProvider();

      final task = Task(
        id: 'code-flutter',
        title: 'Code Flutter',
        priority: TaskPriority.important,
        scheduledStart: DateTime(2026, 8, 28, 22, 50),
        scheduledEnd: DateTime(2026, 8, 28, 22, 55),
        createdAt: DateTime(2026, 8, 28, 22, 45),
      );

      await taskProvider.addTask(task);

      focusProvider.startSession(
        taskId: task.id,
        taskName: task.title,
        totalFocusMinutes: 5,
        focusBlockMinutes: 5,
        breakMinutes: 0,
      );

      now = DateTime(2026, 8, 28, 22, 52);
      focusProvider.endSession();

      // Finishing a focus timer records focus work, but must not silently
      // assert that the user's real-world task itself is finished.
      expect(taskProvider.getTaskById(task.id)!.isCompleted, isFalse);
      expect(
        taskProvider.completedTaskCountForDate(DateTime(2026, 8, 28)),
        0,
      );

      // This is the action triggered by the completion screen's
      // "Mark task complete" button.
      await taskProvider.setCompletedForDate(
        task.id,
        DateTime(2026, 8, 28),
        true,
        completedAt: DateTime(2026, 8, 28, 22, 52),
      );

      expect(taskProvider.getTaskById(task.id)!.isCompleted, isTrue);
      expect(
        taskProvider.completedTaskCountForDate(DateTime(2026, 8, 28)),
        1,
      );
      expect(
        taskProvider.remainingTaskCountForDate(DateTime(2026, 8, 28)),
        0,
      );
    },
  );
}

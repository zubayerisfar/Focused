import 'task.dart';

class TaskOccurrence {
  final Task task;
  final DateTime start;
  final DateTime end;
  final bool isCompleted;
  final DateTime? completedAt;

  const TaskOccurrence({
    required this.task,
    required this.start,
    required this.end,
    this.isCompleted = false,
    this.completedAt,
  });

  Duration get duration => end.difference(start);

  bool get isCompletedLate {
    if (!isCompleted || completedAt == null) return false;
    if (completedAt!.isAfter(end)) return true;
    if (task.deadline != null && completedAt!.isAfter(task.deadline!))
      return true;
    return false;
  }

  TaskOccurrence withCompletion({
    required bool isCompleted,
    DateTime? completedAt,
  }) {
    return TaskOccurrence(
      task: task,
      start: start,
      end: end,
      isCompleted: isCompleted,
      completedAt: completedAt,
    );
  }
}

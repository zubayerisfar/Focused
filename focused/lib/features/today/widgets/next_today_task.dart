import '../../../models/task.dart';
import '../../../models/task_occurrence.dart';
import '../../../providers/task_provider.dart';

class NextTodayTask {
  final Task task;
  final TaskOccurrence? occurrence;
  final DateTime date;

  const NextTodayTask({
    required this.task,
    required this.occurrence,
    required this.date,
  });
}

NextTodayTask? findNextTodayTask({
  required TaskProvider taskProvider,
  required List<TaskOccurrence> schedule,
  required List<Task> todayTasks,
  required DateTime now,
}) {
  final day = DateTime(now.year, now.month, now.day);

  final scheduled =
      schedule.where((occurrence) => !occurrence.isCompleted).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  if (scheduled.isNotEmpty) {
    final future = scheduled.where((occurrence) => occurrence.end.isAfter(now));
    final occurrence = future.isNotEmpty ? future.first : scheduled.first;
    return NextTodayTask(
      task: occurrence.task,
      occurrence: occurrence,
      date: day,
    );
  }

  final unscheduled = todayTasks
      .where((task) => task.scheduledStart == null)
      .toList();
  if (unscheduled.isEmpty) return null;

  unscheduled.sort(
    (a, b) => a.priority.sortOrder.compareTo(b.priority.sortOrder),
  );
  return NextTodayTask(task: unscheduled.first, occurrence: null, date: day);
}

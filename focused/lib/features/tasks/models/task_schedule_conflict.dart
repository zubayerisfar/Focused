import 'task.dart';

class TaskScheduleConflict {
  final Task task;
  final DateTime existingStart;
  final DateTime existingEnd;
  final DateTime candidateStart;
  final DateTime candidateEnd;

  const TaskScheduleConflict({
    required this.task,
    required this.existingStart,
    required this.existingEnd,
    required this.candidateStart,
    required this.candidateEnd,
  });
}

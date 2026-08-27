import 'task.dart';

class TaskOccurrence {
  final Task task;
  final DateTime start;
  final DateTime end;

  const TaskOccurrence({
    required this.task,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}

import 'task_execution_summary.dart';

class TaskExecutionPeriodSummary {
  final DateTime startDay;
  final DateTime endDay;
  final List<TaskExecutionSummary> tasks;

  /// When set, rates only judge occurrences that have actually had a chance
  /// to start/finish by this instant. This prevents a partial current day from
  /// looking artificially bad because of tasks scheduled for later today.
  final DateTime? asOf;

  const TaskExecutionPeriodSummary({
    required this.startDay,
    required this.endDay,
    required this.tasks,
    this.asOf,
  });

  int get scheduledCount => tasks.length;

  Iterable<TaskExecutionSummary> get _startEligibleTasks {
    final cutoff = asOf;
    if (cutoff == null) return tasks;
    return tasks.where(
      (task) => task.hasStarted || !task.plannedStart.isAfter(cutoff),
    );
  }

  Iterable<TaskExecutionSummary> get _completionEligibleTasks {
    final cutoff = asOf;
    if (cutoff == null) return tasks;
    return tasks.where(
      (task) => task.isCompleted || !task.plannedEnd.isAfter(cutoff),
    );
  }

  int get startEligibleCount => _startEligibleTasks.length;
  int get completionEligibleCount => _completionEligibleTasks.length;

  int get startedCount =>
      _startEligibleTasks.where((task) => task.hasStarted).length;
  int get completedCount =>
      _completionEligibleTasks.where((task) => task.isCompleted).length;
  int get activeCount => tasks.where((task) => task.isActive).length;
  int get onTimeStartedCount => _startEligibleTasks
      .where((task) => task.hasStarted && task.startedOnTime)
      .length;

  Duration get plannedDuration => tasks.fold(Duration.zero, (total, task) {
    return total + task.plannedDuration;
  });

  Duration get elapsedPlannedDuration {
    final cutoff = asOf;
    if (cutoff == null) return plannedDuration;

    return tasks.fold(Duration.zero, (total, task) {
      if (!cutoff.isAfter(task.plannedStart)) {
        return total;
      }
      final end = cutoff.isBefore(task.plannedEnd) ? cutoff : task.plannedEnd;
      if (!end.isAfter(task.plannedStart)) return total;
      return total + end.difference(task.plannedStart);
    });
  }

  Duration get activeFocusDuration => tasks.fold(Duration.zero, (total, task) {
    return total + task.activeFocusDuration;
  });

  bool get effectiveFocusAvailable {
    final started = tasks.where((task) => task.hasStarted);
    if (started.isEmpty) return true;
    return started.every((task) => task.focusAnalysisComplete);
  }

  Duration? get effectiveFocusDuration {
    if (!effectiveFocusAvailable) return null;
    return tasks.fold<Duration>(Duration.zero, (total, task) {
      return total + (task.effectiveFocusDuration ?? Duration.zero);
    });
  }

  Duration? get distractedDuration {
    if (!effectiveFocusAvailable) return null;
    return tasks.fold<Duration>(Duration.zero, (total, task) {
      return total + (task.distractedDuration ?? Duration.zero);
    });
  }

  int? get interruptionCount {
    if (!effectiveFocusAvailable) return null;
    return tasks.fold<int>(0, (total, task) {
      return total + (task.interruptionCount ?? 0);
    });
  }

  double get startRatePercent {
    if (startEligibleCount == 0) return 0;
    return startedCount / startEligibleCount * 100;
  }

  double get completionRatePercent {
    if (completionEligibleCount == 0) return 0;
    return completedCount / completionEligibleCount * 100;
  }

  double get onTimeRatePercent {
    if (startedCount == 0) return 0;
    return onTimeStartedCount / startedCount * 100;
  }

  Duration? get averageStartDelay {
    final started = _startEligibleTasks
        .where((task) => task.hasStarted)
        .toList();
    if (started.isEmpty) return null;

    var totalMicroseconds = 0;
    for (final task in started) {
      totalMicroseconds += (task.startDelay ?? Duration.zero).inMicroseconds;
    }

    return Duration(microseconds: totalMicroseconds ~/ started.length);
  }

  double get planCoveragePercent {
    final plannedSeconds = elapsedPlannedDuration.inSeconds;
    if (plannedSeconds <= 0) return 0;
    return activeFocusDuration.inSeconds / plannedSeconds * 100;
  }

  double? get effectiveCoveragePercent {
    final effective = effectiveFocusDuration;
    final plannedSeconds = elapsedPlannedDuration.inSeconds;
    if (effective == null || plannedSeconds <= 0) return null;
    return effective.inSeconds / plannedSeconds * 100;
  }
}

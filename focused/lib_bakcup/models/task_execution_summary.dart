import 'task.dart';

class TaskExecutionSummary {
  final Task task;
  final DateTime occurrenceDate;
  final DateTime plannedStart;
  final DateTime plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final Duration activeFocusDuration;
  final Duration? distractedDuration;
  final Duration? effectiveFocusDuration;
  final int sessionCount;
  final int? interruptionCount;
  final String? topInterrupterApp;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isActive;
  final bool focusAnalysisComplete;

  const TaskExecutionSummary({
    required this.task,
    required this.occurrenceDate,
    required this.plannedStart,
    required this.plannedEnd,
    required this.actualStart,
    required this.actualEnd,
    required this.activeFocusDuration,
    required this.distractedDuration,
    required this.effectiveFocusDuration,
    required this.sessionCount,
    required this.interruptionCount,
    required this.topInterrupterApp,
    required this.isCompleted,
    required this.completedAt,
    required this.isActive,
    required this.focusAnalysisComplete,
  });

  Duration get plannedDuration => plannedEnd.difference(plannedStart);

  bool get hasStarted => actualStart != null;

  Duration? get startOffset =>
      actualStart == null ? null : actualStart!.difference(plannedStart);

  Duration? get startDelay {
    final offset = startOffset;
    if (offset == null || offset.isNegative) {
      return offset == null ? null : Duration.zero;
    }
    return offset;
  }

  Duration? get earlyBy {
    final offset = startOffset;
    if (offset == null || !offset.isNegative) {
      return offset == null ? null : Duration.zero;
    }
    return Duration(microseconds: -offset.inMicroseconds);
  }

  bool get startedOnTime {
    final offset = startOffset;
    if (offset == null) return false;

    // Starting early is never penalized. A five-minute grace period prevents
    // small clock/tap delays from being treated as schedule failure.
    return offset.compareTo(const Duration(minutes: 5)) <= 0;
  }

  double get planCoveragePercent {
    final plannedSeconds = plannedDuration.inSeconds;
    if (plannedSeconds <= 0) return 0;
    return activeFocusDuration.inSeconds / plannedSeconds * 100;
  }

  double? get effectiveCoveragePercent {
    final effective = effectiveFocusDuration;
    final plannedSeconds = plannedDuration.inSeconds;
    if (effective == null || plannedSeconds <= 0) return null;
    return effective.inSeconds / plannedSeconds * 100;
  }

  String get occurrenceKey {
    final day = occurrenceDate;
    return '${task.id}|${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }
}

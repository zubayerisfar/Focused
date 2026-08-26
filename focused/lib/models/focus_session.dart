import 'focus_block.dart';

class FocusInterval {
  final DateTime startTime;
  final DateTime endTime;

  const FocusInterval({required this.startTime, required this.endTime});

  Duration get duration {
    return endTime.difference(startTime);
  }
}

class FocusSession {
  final String id;
  final String taskName;

  final DateTime startedAt;
  final DateTime endedAt;

  final Duration plannedFocusDuration;

  final List<FocusBlock> plan;
  final List<FocusInterval> focusIntervals;

  final int completedFocusBlocks;

  final bool completedNaturally;

  const FocusSession({
    required this.id,
    required this.taskName,
    required this.startedAt,
    required this.endedAt,
    required this.plannedFocusDuration,
    required this.plan,
    required this.focusIntervals,
    required this.completedFocusBlocks,
    required this.completedNaturally,
  });

  Duration get actualFocusDuration {
    return focusIntervals.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }

  Duration get totalElapsedDuration {
    return endedAt.difference(startedAt);
  }

  int get totalFocusBlocks {
    return plan.where((block) => block.isFocus).length;
  }
}

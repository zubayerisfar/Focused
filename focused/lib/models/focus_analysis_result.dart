import 'focus_interruption.dart';

class FocusAnalysisResult {
  final DateTime focusStart;
  final DateTime focusEnd;

  final Duration plannedDuration;
  final Duration distractedDuration;
  final Duration effectiveFocusDuration;

  final int interruptionCount;

  final double focusQuality;

  final String? topInterrupterApp;

  final Map<String, Duration> distractionByApp;

  final List<FocusInterruption> interruptions;

  const FocusAnalysisResult({
    required this.focusStart,
    required this.focusEnd,
    required this.plannedDuration,
    required this.distractedDuration,
    required this.effectiveFocusDuration,
    required this.interruptionCount,
    required this.focusQuality,
    required this.topInterrupterApp,
    required this.distractionByApp,
    required this.interruptions,
  });
}

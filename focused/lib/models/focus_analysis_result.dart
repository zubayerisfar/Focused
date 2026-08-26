import 'focus_interruption.dart';

class FocusAnalysisResult {
  final DateTime focusStart;
  final DateTime focusEnd;

  /// What the user originally planned.
  final Duration plannedDuration;

  /// Time the focus timer was genuinely active.
  /// Pauses and breaks are excluded.
  final Duration actualFocusDuration;

  /// Unique distracting time during active focus.
  /// Overlapping distraction intervals are NOT double-counted.
  final Duration distractedDuration;

  /// actualFocusDuration - distractedDuration
  final Duration effectiveFocusDuration;

  /// Number of continuous distraction episodes.
  ///
  /// Instagram 10:10-10:15
  /// WhatsApp  10:15-10:20
  ///
  /// = 1 continuous interruption episode, not 2.
  final int interruptionCount;

  /// actualFocus / plannedFocus
  final double completionRate;

  /// effectiveFocus / actualFocus
  final double attentionRetention;

  /// effectiveFocus / plannedFocus
  final double focusQuality;

  final String? topInterrupterApp;

  final Map<String, Duration> distractionByApp;

  final List<FocusInterruption> interruptions;

  const FocusAnalysisResult({
    required this.focusStart,
    required this.focusEnd,
    required this.plannedDuration,
    required this.actualFocusDuration,
    required this.distractedDuration,
    required this.effectiveFocusDuration,
    required this.interruptionCount,
    required this.completionRate,
    required this.attentionRetention,
    required this.focusQuality,
    required this.topInterrupterApp,
    required this.distractionByApp,
    required this.interruptions,
  });
}

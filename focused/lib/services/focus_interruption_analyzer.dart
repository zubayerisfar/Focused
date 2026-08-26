import '../models/app_category.dart';
import '../models/app_usage_record.dart';
import '../models/focus_analysis_result.dart';
import '../models/focus_interruption.dart';

class FocusInterruptionAnalyzer {
  FocusAnalysisResult analyze({
    required DateTime focusStart,
    required DateTime focusEnd,
    required List<AppUsageRecord> usageRecords,
    required Map<String, AppCategory> appCategories,
  }) {
    if (!focusEnd.isAfter(focusStart)) {
      throw ArgumentError('Focus end time must be after focus start time.');
    }

    final plannedDuration = focusEnd.difference(focusStart);

    final List<FocusInterruption> interruptions = [];

    final Map<String, Duration> distractionByApp = {};

    for (final record in usageRecords) {
      final overlapsFocus =
          record.endTime.isAfter(focusStart) &&
          record.startTime.isBefore(focusEnd);

      if (!overlapsFocus) {
        continue;
      }

      final category = appCategories[record.appName] ?? AppCategory.neutral;

      if (category != AppCategory.distracting) {
        continue;
      }

      final interruptionStart = record.startTime.isBefore(focusStart)
          ? focusStart
          : record.startTime;

      final interruptionEnd = record.endTime.isAfter(focusEnd)
          ? focusEnd
          : record.endTime;

      if (!interruptionEnd.isAfter(interruptionStart)) {
        continue;
      }

      final interruption = FocusInterruption(
        appId: record.appId,
        appName: record.appName,
        startTime: interruptionStart,
        endTime: interruptionEnd,
      );

      interruptions.add(interruption);

      final currentDuration = distractionByApp[record.appName] ?? Duration.zero;

      distractionByApp[record.appName] =
          currentDuration + interruption.duration;
    }

    interruptions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final distractedDuration = _calculateTotalDistractedTime(interruptions);

    final effectiveSeconds =
        (plannedDuration.inSeconds - distractedDuration.inSeconds).clamp(
          0,
          plannedDuration.inSeconds,
        );

    final effectiveFocusDuration = Duration(seconds: effectiveSeconds);

    final focusQuality = plannedDuration.inSeconds == 0
        ? 0.0
        : (effectiveFocusDuration.inSeconds / plannedDuration.inSeconds) * 100;

    String? topInterrupterApp;

    if (distractionByApp.isNotEmpty) {
      final sortedApps = distractionByApp.entries.toList()
        ..sort((a, b) => b.value.inSeconds.compareTo(a.value.inSeconds));

      topInterrupterApp = sortedApps.first.key;
    }

    return FocusAnalysisResult(
      focusStart: focusStart,
      focusEnd: focusEnd,
      plannedDuration: plannedDuration,
      distractedDuration: distractedDuration,
      effectiveFocusDuration: effectiveFocusDuration,
      interruptionCount: interruptions.length,
      focusQuality: focusQuality,
      topInterrupterApp: topInterrupterApp,
      distractionByApp: Map<String, Duration>.unmodifiable(distractionByApp),
      interruptions: List<FocusInterruption>.unmodifiable(interruptions),
    );
  }

  Duration _calculateTotalDistractedTime(
    List<FocusInterruption> interruptions,
  ) {
    if (interruptions.isEmpty) {
      return Duration.zero;
    }

    final sorted = List<FocusInterruption>.from(interruptions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    DateTime currentStart = sorted.first.startTime;
    DateTime currentEnd = sorted.first.endTime;

    int totalSeconds = 0;

    for (int i = 1; i < sorted.length; i++) {
      final interruption = sorted[i];

      if (!interruption.startTime.isAfter(currentEnd)) {
        if (interruption.endTime.isAfter(currentEnd)) {
          currentEnd = interruption.endTime;
        }
      } else {
        totalSeconds += currentEnd.difference(currentStart).inSeconds;

        currentStart = interruption.startTime;
        currentEnd = interruption.endTime;
      }
    }

    totalSeconds += currentEnd.difference(currentStart).inSeconds;

    return Duration(seconds: totalSeconds);
  }
}

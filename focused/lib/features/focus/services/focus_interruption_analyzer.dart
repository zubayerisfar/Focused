import '../../wellbeing/models/app_category.dart';
import '../../wellbeing/models/app_usage_record.dart';
import '../models/focus_analysis_result.dart';
import '../models/focus_interruption.dart';
import '../models/focus_session.dart';

class FocusInterruptionAnalyzer {
  FocusAnalysisResult analyzeSession({
    required FocusSession session,
    required List<AppUsageRecord> usageRecords,
    required Map<String, AppCategory> appCategories,
  }) {
    // ---------------------------------------------------------
    // 1. Normalize the real focus intervals.
    //
    // This protects us if overlapping focus intervals somehow
    // reach the analyzer because of an upstream bug.
    // ---------------------------------------------------------

    final focusRanges = _mergeRanges(
      session.focusIntervals.map(
        (interval) => _TimeRange(
          start: interval.startTime,
          end: interval.endTime,
        ),
      ),
    );

    final actualFocusDuration =
        _sumRanges(focusRanges);

    // ---------------------------------------------------------
    // 2. Find distracting app usage that intersects
    //    actual focus time.
    // ---------------------------------------------------------

    final Map<String, List<_TimeRange>>
        distractionRangesByApp = {};

    final Map<String, String> appIds = {};

    for (final record in usageRecords) {
      // Invalid/zero-length records cannot contribute time.
      if (!record.endTime.isAfter(
        record.startTime,
      )) {
        continue;
      }

      final category =
          appCategories[record.appId] ??
              appCategories[record.appName] ??
              AppCategory.neutral;

      if (category !=
          AppCategory.distracting) {
        continue;
      }

      appIds.putIfAbsent(
        record.appName,
        () => record.appId,
      );

      for (final focusRange in focusRanges) {
        final intersection =
            _intersection(
          _TimeRange(
            start: record.startTime,
            end: record.endTime,
          ),
          focusRange,
        );

        if (intersection == null) {
          continue;
        }

        distractionRangesByApp
            .putIfAbsent(
              record.appName,
              () => [],
            )
            .add(intersection);
      }
    }

    // ---------------------------------------------------------
    // 3. Merge duplicate/overlapping records for each app.
    // ---------------------------------------------------------

    final Map<String, Duration>
        distractionByApp = {};

    final List<FocusInterruption>
        interruptions = [];

    for (final entry
        in distractionRangesByApp.entries) {
      final appName = entry.key;

      final mergedRanges =
          _mergeRanges(entry.value);

      distractionByApp[appName] =
          _sumRanges(mergedRanges);

      for (final range in mergedRanges) {
        interruptions.add(
          FocusInterruption(
            appId: appIds[appName] ?? appName,
            appName: appName,
            startTime: range.start,
            endTime: range.end,
          ),
        );
      }
    }

    interruptions.sort(
      (a, b) =>
          a.startTime.compareTo(b.startTime),
    );

    // ---------------------------------------------------------
    // 4. Merge ALL distracting ranges globally.
    //
    // This prevents overlapping distracting records from
    // double-counting distracted time.
    // ---------------------------------------------------------

    final distractionEpisodes =
        _mergeRanges(
      interruptions.map(
        (interruption) => _TimeRange(
          start: interruption.startTime,
          end: interruption.endTime,
        ),
      ),
    );

    final distractedDuration =
        _sumRanges(distractionEpisodes);

    // ---------------------------------------------------------
    // 5. Effective focus
    // ---------------------------------------------------------

    final effectiveSeconds =
        (actualFocusDuration.inSeconds -
                distractedDuration.inSeconds)
            .clamp(
      0,
      actualFocusDuration.inSeconds,
    );

    final effectiveFocusDuration =
        Duration(
      seconds: effectiveSeconds,
    );

    // ---------------------------------------------------------
    // 6. Percentage calculations
    // ---------------------------------------------------------

    final plannedSeconds =
        session.plannedFocusDuration.inSeconds;

    final actualSeconds =
        actualFocusDuration.inSeconds;

    final effective =
        effectiveFocusDuration.inSeconds;

    final completionRate =
        plannedSeconds <= 0
            ? 0.0
            : ((actualSeconds /
                            plannedSeconds) *
                        100)
                    .clamp(0.0, 100.0)
                    .toDouble();

    final attentionRetention =
        actualSeconds <= 0
            ? 0.0
            : ((effective /
                            actualSeconds) *
                        100)
                    .clamp(0.0, 100.0)
                    .toDouble();

    final focusQuality =
        plannedSeconds <= 0
            ? 0.0
            : ((effective /
                            plannedSeconds) *
                        100)
                    .clamp(0.0, 100.0)
                    .toDouble();

    // ---------------------------------------------------------
    // 7. Top distracting app
    // ---------------------------------------------------------

    String? topInterrupterApp;

    if (distractionByApp.isNotEmpty) {
      final sorted =
          distractionByApp.entries.toList()
            ..sort(
              (a, b) =>
                  b.value.inSeconds.compareTo(
                a.value.inSeconds,
              ),
            );

      topInterrupterApp =
          sorted.first.key;
    }

    return FocusAnalysisResult(
      focusStart: session.startedAt,
      focusEnd: session.endedAt,
      plannedDuration:
          session.plannedFocusDuration,
      actualFocusDuration:
          actualFocusDuration,
      distractedDuration:
          distractedDuration,
      effectiveFocusDuration:
          effectiveFocusDuration,

      // Continuous distraction periods,
      // not number of raw OS records.
      interruptionCount:
          distractionEpisodes.length,

      completionRate: completionRate,
      attentionRetention:
          attentionRetention,
      focusQuality: focusQuality,
      topInterrupterApp:
          topInterrupterApp,
      distractionByApp:
          Map.unmodifiable(
        distractionByApp,
      ),
      interruptions:
          List.unmodifiable(
        interruptions,
      ),
    );
  }

  // ===========================================================
  // INTERVAL MATHEMATICS
  // ===========================================================

  _TimeRange? _intersection(
    _TimeRange first,
    _TimeRange second,
  ) {
    final start =
        first.start.isAfter(second.start)
            ? first.start
            : second.start;

    final end =
        first.end.isBefore(second.end)
            ? first.end
            : second.end;

    if (!end.isAfter(start)) {
      return null;
    }

    return _TimeRange(
      start: start,
      end: end,
    );
  }

  List<_TimeRange> _mergeRanges(
    Iterable<_TimeRange> ranges,
  ) {
    final validRanges = ranges
        .where(
          (range) =>
              range.end.isAfter(range.start),
        )
        .toList();

    if (validRanges.isEmpty) {
      return [];
    }

    validRanges.sort(
      (a, b) => a.start.compareTo(b.start),
    );

    final List<_TimeRange> merged = [];

    var current = validRanges.first;

    for (int i = 1;
        i < validRanges.length;
        i++) {
      final next = validRanges[i];

      // Overlapping OR directly touching ranges
      // are one continuous interval.
      if (!next.start.isAfter(current.end)) {
        final laterEnd =
            next.end.isAfter(current.end)
                ? next.end
                : current.end;

        current = _TimeRange(
          start: current.start,
          end: laterEnd,
        );
      } else {
        merged.add(current);

        current = next;
      }
    }

    merged.add(current);

    return merged;
  }

  Duration _sumRanges(
    Iterable<_TimeRange> ranges,
  ) {
    int totalMilliseconds = 0;

    for (final range in ranges) {
      totalMilliseconds +=
          range.end
              .difference(range.start)
              .inMilliseconds;
    }

    return Duration(
      milliseconds: totalMilliseconds,
    );
  }
}

class _TimeRange {
  final DateTime start;
  final DateTime end;

  const _TimeRange({
    required this.start,
    required this.end,
  });
}
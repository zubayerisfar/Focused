import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../models/hourly_usage_summary.dart';

class UsageAnalyzer {
  DailyUsageSummary buildDailySummary(
    DateTime day,
    List<AppUsageRecord> records,
  ) {
    // Use calendar midnights rather than simply adding
    // Duration(days: 1).
    //
    // This is safer for users in locations where a calendar
    // day can be affected by daylight-saving transitions.
    final dayStart = DateTime(day.year, day.month, day.day);

    final dayEnd = DateTime(day.year, day.month, day.day + 1);

    // -------------------------------------------------------
    // 1. Validate and clip records to this calendar day.
    // -------------------------------------------------------

    final Map<String, List<_TimeRange>> rangesByApp = {};

    final List<_TimeRange> allRanges = [];

    for (final record in records) {
      // Invalid or zero-duration records are ignored.
      if (!record.endTime.isAfter(record.startTime)) {
        continue;
      }

      final recordRange = _TimeRange(
        start: record.startTime,
        end: record.endTime,
      );

      final clipped = _intersection(
        recordRange,
        _TimeRange(start: dayStart, end: dayEnd),
      );

      // Record does not touch this day.
      if (clipped == null) {
        continue;
      }

      rangesByApp.putIfAbsent(record.appName, () => []).add(clipped);

      allRanges.add(clipped);
    }

    // -------------------------------------------------------
    // 2. Calculate per-app daily usage.
    //
    // Duplicate/overlapping records for the SAME app are
    // merged first.
    // -------------------------------------------------------

    final Map<String, List<_TimeRange>> normalizedRangesByApp = {};

    final Map<String, Duration> dailyAppUsage = {};

    for (final entry in rangesByApp.entries) {
      final merged = _mergeRanges(entry.value);

      normalizedRangesByApp[entry.key] = merged;

      dailyAppUsage[entry.key] = _sumRanges(merged);
    }

    // -------------------------------------------------------
    // 3. Calculate UNIQUE daily screen time.
    //
    // Different apps can overlap because of duplicate OS
    // events, multi-window behaviour, or noisy source data.
    //
    // Total screen time must not double-count those overlaps.
    // -------------------------------------------------------

    final mergedGlobalRanges = _mergeRanges(allRanges);

    final totalUsage = _sumRanges(mergedGlobalRanges);

    // -------------------------------------------------------
    // 4. Build hourly buckets.
    //
    // We create buckets from local midnight until the next
    // local midnight.
    //
    // A normal day gives 24 buckets. A daylight-saving day
    // may eventually produce 23 or 25 actual hourly buckets.
    // -------------------------------------------------------

    final List<HourlyUsageSummary> hourlySummaries = [];

    var hourStart = dayStart;

    while (hourStart.isBefore(dayEnd)) {
      var hourEnd = hourStart.add(const Duration(hours: 1));

      if (hourEnd.isAfter(dayEnd)) {
        hourEnd = dayEnd;
      }

      final hourRange = _TimeRange(start: hourStart, end: hourEnd);

      final Map<String, Duration> hourlyAppUsage = {};

      final List<_TimeRange> allHourlyRanges = [];

      for (final entry in normalizedRangesByApp.entries) {
        final appName = entry.key;

        final List<_TimeRange> appHourlyRanges = [];

        for (final appRange in entry.value) {
          final overlap = _intersection(appRange, hourRange);

          if (overlap != null) {
            appHourlyRanges.add(overlap);
            allHourlyRanges.add(overlap);
          }
        }

        if (appHourlyRanges.isNotEmpty) {
          final mergedAppHourlyRanges = _mergeRanges(appHourlyRanges);

          hourlyAppUsage[appName] = _sumRanges(mergedAppHourlyRanges);
        }
      }

      final uniqueHourlyUsage = _sumRanges(_mergeRanges(allHourlyRanges));

      hourlySummaries.add(
        HourlyUsageSummary(
          hourStart: hourStart,
          totalUsage: uniqueHourlyUsage,
          appUsage: Map<String, Duration>.unmodifiable(hourlyAppUsage),
        ),
      );

      hourStart = hourEnd;
    }

    return DailyUsageSummary(
      date: dayStart,
      totalUsage: totalUsage,
      appUsage: Map<String, Duration>.unmodifiable(dailyAppUsage),
      hourlyUsage: List<HourlyUsageSummary>.unmodifiable(hourlySummaries),
    );
  }

  // =========================================================
  // INTERVAL MATHEMATICS
  // =========================================================

  _TimeRange? _intersection(_TimeRange first, _TimeRange second) {
    final start = first.start.isAfter(second.start)
        ? first.start
        : second.start;

    final end = first.end.isBefore(second.end) ? first.end : second.end;

    if (!end.isAfter(start)) {
      return null;
    }

    return _TimeRange(start: start, end: end);
  }

  List<_TimeRange> _mergeRanges(Iterable<_TimeRange> ranges) {
    final valid = ranges
        .where((range) => range.end.isAfter(range.start))
        .toList();

    if (valid.isEmpty) {
      return [];
    }

    valid.sort((a, b) => a.start.compareTo(b.start));

    final List<_TimeRange> merged = [];

    var current = valid.first;

    for (int i = 1; i < valid.length; i++) {
      final next = valid[i];

      // Overlapping or directly touching intervals belong
      // to one continuous period.
      if (!next.start.isAfter(current.end)) {
        current = _TimeRange(
          start: current.start,
          end: next.end.isAfter(current.end) ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);

    return merged;
  }

  Duration _sumRanges(Iterable<_TimeRange> ranges) {
    int milliseconds = 0;

    for (final range in ranges) {
      milliseconds += range.end.difference(range.start).inMilliseconds;
    }

    return Duration(milliseconds: milliseconds);
  }
}

class _TimeRange {
  final DateTime start;
  final DateTime end;

  const _TimeRange({required this.start, required this.end});
}

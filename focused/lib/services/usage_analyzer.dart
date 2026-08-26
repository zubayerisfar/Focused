import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../models/hourly_usage_summary.dart';

class UsageAnalyzer {
  DailyUsageSummary buildDailySummary(
    DateTime day,
    List<AppUsageRecord> records,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);

    final dayEnd = dayStart.add(const Duration(days: 1));

    final Map<String, Duration> dailyAppUsage = {};

    final Map<DateTime, Map<String, Duration>> hourlyAppUsage = {};

    for (final record in records) {
      // Ignore records that do not touch this day.
      if (!record.endTime.isAfter(dayStart) ||
          !record.startTime.isBefore(dayEnd)) {
        continue;
      }

      // If an app started yesterday or ends tomorrow,
      // only use the part inside this day.
      final clippedStart = record.startTime.isBefore(dayStart)
          ? dayStart
          : record.startTime;

      final clippedEnd = record.endTime.isAfter(dayEnd)
          ? dayEnd
          : record.endTime;

      final recordDuration = clippedEnd.difference(clippedStart);

      _addDuration(dailyAppUsage, record.appName, recordDuration);

      // Split the record into hourly pieces.
      var currentTime = clippedStart;

      while (currentTime.isBefore(clippedEnd)) {
        final hourStart = DateTime(
          currentTime.year,
          currentTime.month,
          currentTime.day,
          currentTime.hour,
        );

        final nextHour = hourStart.add(const Duration(hours: 1));

        final segmentEnd = clippedEnd.isBefore(nextHour)
            ? clippedEnd
            : nextHour;

        final segmentDuration = segmentEnd.difference(currentTime);

        final appMap = hourlyAppUsage.putIfAbsent(hourStart, () => {});

        _addDuration(appMap, record.appName, segmentDuration);

        currentTime = segmentEnd;
      }
    }

    final List<HourlyUsageSummary> hourlySummaries = [];

    for (int hour = 0; hour < 24; hour++) {
      final hourStart = dayStart.add(Duration(hours: hour));

      hourlySummaries.add(
        HourlyUsageSummary(
          hourStart: hourStart,
          appUsage: Map<String, Duration>.unmodifiable(
            hourlyAppUsage[hourStart] ?? {},
          ),
        ),
      );
    }

    return DailyUsageSummary(
      date: dayStart,
      appUsage: Map<String, Duration>.unmodifiable(dailyAppUsage),
      hourlyUsage: hourlySummaries,
    );
  }

  void _addDuration(
    Map<String, Duration> map,
    String appName,
    Duration duration,
  ) {
    final existingDuration = map[appName] ?? Duration.zero;

    map[appName] = existingDuration + duration;
  }
}

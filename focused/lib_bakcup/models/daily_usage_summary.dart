import 'hourly_usage_summary.dart';

class DailyUsageSummary {
  final DateTime date;

  /// Unique screen-active time for the calendar day.
  ///
  /// This must never be inflated by duplicate or overlapping
  /// app records.
  final Duration totalUsage;

  /// Usage attributed to individual apps.
  ///
  /// In unusual overlapping/multi-window data, the sum of
  /// per-app usage may be greater than totalUsage. That does
  /// NOT mean total screen time is greater.
  final Map<String, Duration> appUsage;

  final List<HourlyUsageSummary> hourlyUsage;

  const DailyUsageSummary({
    required this.date,
    required this.totalUsage,
    required this.appUsage,
    required this.hourlyUsage,
  });

  String? get mostUsedApp {
    if (appUsage.isEmpty) {
      return null;
    }

    final entries = appUsage.entries.toList()
      ..sort(
        (a, b) => b.value.inMilliseconds.compareTo(a.value.inMilliseconds),
      );

    return entries.first.key;
  }
}

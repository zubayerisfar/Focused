class HourlyUsageSummary {
  final DateTime hourStart;

  /// Unique screen-active time during this hour.
  ///
  /// Overlapping app records do not inflate this value.
  final Duration totalUsage;

  /// Usage attributed to individual apps.
  final Map<String, Duration> appUsage;

  const HourlyUsageSummary({
    required this.hourStart,
    required this.totalUsage,
    required this.appUsage,
  });
}

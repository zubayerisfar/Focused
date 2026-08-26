class HourlyUsageSummary {
  final DateTime hourStart;
  final Map<String, Duration> appUsage;

  const HourlyUsageSummary({required this.hourStart, required this.appUsage});

  Duration get totalUsage {
    return appUsage.values.fold(
      Duration.zero,
      (total, duration) => total + duration,
    );
  }
}

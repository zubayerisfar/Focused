import 'hourly_usage_summary.dart';

class DailyUsageSummary {
  final DateTime date;
  final Map<String, Duration> appUsage;
  final List<HourlyUsageSummary> hourlyUsage;

  const DailyUsageSummary({
    required this.date,
    required this.appUsage,
    required this.hourlyUsage,
  });

  Duration get totalUsage {
    return appUsage.values.fold(
      Duration.zero,
      (total, duration) => total + duration,
    );
  }

  String? get mostUsedApp {
    if (appUsage.isEmpty) {
      return null;
    }

    final entries = appUsage.entries.toList();

    entries.sort((a, b) => b.value.inSeconds.compareTo(a.value.inSeconds));

    return entries.first.key;
  }
}

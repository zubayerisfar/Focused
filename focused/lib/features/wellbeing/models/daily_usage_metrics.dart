import 'app_usage_app_entry.dart';
import 'usage_data_provenance.dart';

class DailyUsageMetrics {
  final DateTime day;
  final UsageDataProvenance provenance;
  final bool completeDay;
  final Duration totalUsage;
  final Duration productiveUsage;
  final Duration neutralUsage;
  final Duration distractingUsage;
  final List<AppUsageAppEntry> topApps;

  const DailyUsageMetrics({
    required this.day,
    required this.provenance,
    this.completeDay = true,
    required this.totalUsage,
    required this.productiveUsage,
    required this.neutralUsage,
    required this.distractingUsage,
    required this.topApps,
  });

  bool get measured => provenance.measured;
}

import 'usage_data_provenance.dart';

class AppUsageHistoryPoint {
  final DateTime day;
  final Duration usage;

  /// True when Focused has a trustworthy measurement for this day.
  final bool measured;

  /// False for an in-progress current-day snapshot. Partial days are useful to
  /// show, but they must not be compared as if they represented 24 hours.
  final bool completeDay;

  /// Where the value shown in this history view came from.
  final UsageDataProvenance provenance;

  const AppUsageHistoryPoint({
    required this.day,
    required this.usage,
    required this.measured,
    bool? completeDay,
    UsageDataProvenance? provenance,
  })  : completeDay = completeDay ?? measured,
        provenance = provenance ??
            (measured
                ? UsageDataProvenance.focusedStorage
                : UsageDataProvenance.missing);
}

import '../models/app_open_event.dart';
import '../models/app_usage_record.dart';

abstract class UsageStatsService {
  bool get isSupported;

  Future<bool> hasUsageAccess();

  Future<void> requestUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end, {
    bool reconcileWithDailyAggregates = true,
  });

  /// Queries the OS's cumulative foreground usage statistics for the given interval.
  ///
  /// Returns a map of packageId -> total foreground Duration as tracked by
  /// Android's system daemon (the source for Digital Wellbeing).
  Future<Map<String, Duration>> queryDailyAggregateUsage(
    DateTime start,
    DateTime end,
  );

  /// Counts foreground transitions at the package level.
  ///
  /// A new opening is emitted only when the foreground package changes from
  /// another package to this package. Activity navigation inside one package
  /// therefore does not inflate the count.
  Future<List<AppOpenEvent>> queryAppOpenEvents(DateTime start, DateTime end);
}

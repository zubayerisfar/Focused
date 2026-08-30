import '../models/app_usage_record.dart';

abstract class UsageStatsService {
  bool get isSupported;

  Future<bool> hasUsageAccess();

  Future<void> requestUsageAccess();

  Future<void> openUsageAccessSettings();

  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  );
}

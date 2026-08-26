class AppUsageRecord {
  final String appId;
  final String appName;
  final DateTime startTime;
  final DateTime endTime;

  const AppUsageRecord({
    required this.appId,
    required this.appName,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration {
    return endTime.difference(startTime);
  }
}

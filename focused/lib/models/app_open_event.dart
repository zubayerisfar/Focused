class AppOpenEvent {
  const AppOpenEvent({
    required this.appId,
    required this.appName,
    required this.timestamp,
  });

  final String appId;
  final String appName;
  final DateTime timestamp;
}

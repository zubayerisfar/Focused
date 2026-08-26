class FocusInterruption {
  final String appId;
  final String appName;
  final DateTime startTime;
  final DateTime endTime;

  const FocusInterruption({
    required this.appId,
    required this.appName,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration {
    return endTime.difference(startTime);
  }
}

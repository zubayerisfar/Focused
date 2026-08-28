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

  Duration get duration => endTime.difference(startTime);

  bool overlaps(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      return false;
    }

    return startTime.isBefore(end) && endTime.isAfter(start);
  }

  AppUsageRecord copyWith({
    String? appId,
    String? appName,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return AppUsageRecord(
      appId: appId ?? this.appId,
      appName: appName ?? this.appName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'appId': appId,
      'appName': appName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory AppUsageRecord.fromMap(Map<dynamic, dynamic> map) {
    final appId = map['appId'];
    final appName = map['appName'];
    final startRaw = map['startTime'];
    final endRaw = map['endTime'];

    if (appId is! String || appId.trim().isEmpty) {
      throw const FormatException('Invalid app usage appId.');
    }

    if (appName is! String || appName.trim().isEmpty) {
      throw const FormatException('Invalid app usage appName.');
    }

    if (startRaw is! String || endRaw is! String) {
      throw const FormatException('Invalid app usage timestamps.');
    }

    final startTime = DateTime.tryParse(startRaw);
    final endTime = DateTime.tryParse(endRaw);

    if (startTime == null || endTime == null || !endTime.isAfter(startTime)) {
      throw const FormatException('Invalid app usage interval.');
    }

    return AppUsageRecord(
      appId: appId,
      appName: appName,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

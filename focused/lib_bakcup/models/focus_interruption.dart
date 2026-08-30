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

  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'appName': appName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory FocusInterruption.fromMap(Map<dynamic, dynamic> map) {
    final appId = map['appId'];
    final appName = map['appName'];
    final start = map['startTime'];
    final end = map['endTime'];

    if (appId is! String || appId.trim().isEmpty) {
      throw const FormatException('Invalid interruption appId.');
    }
    if (appName is! String || appName.trim().isEmpty) {
      throw const FormatException('Invalid interruption appName.');
    }
    if (start is! String || end is! String) {
      throw const FormatException('Invalid interruption time.');
    }

    final startTime = DateTime.tryParse(start);
    final endTime = DateTime.tryParse(end);
    if (startTime == null || endTime == null || !endTime.isAfter(startTime)) {
      throw const FormatException('Invalid interruption interval.');
    }

    return FocusInterruption(
      appId: appId,
      appName: appName,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

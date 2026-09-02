class AppLimit {
  final String packageId;
  final String appName;
  final int dailyLimitMinutes;
  final bool isEnabled;
  final DateTime? lastWarningDate;

  const AppLimit({
    required this.packageId,
    required this.appName,
    required this.dailyLimitMinutes,
    this.isEnabled = true,
    this.lastWarningDate,
  });

  AppLimit copyWith({
    String? packageId,
    String? appName,
    int? dailyLimitMinutes,
    bool? isEnabled,
    DateTime? lastWarningDate,
    bool clearWarningDate = false,
  }) {
    return AppLimit(
      packageId: packageId ?? this.packageId,
      appName: appName ?? this.appName,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      lastWarningDate: clearWarningDate
          ? null
          : (lastWarningDate ?? this.lastWarningDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'packageId': packageId,
      'appName': appName,
      'dailyLimitMinutes': dailyLimitMinutes,
      'isEnabled': isEnabled,
      'lastWarningDate': lastWarningDate?.toIso8601String(),
    };
  }

  factory AppLimit.fromMap(Map<dynamic, dynamic> map) {
    final packageId = map['packageId'];
    final appName = map['appName'];
    final dailyLimitMinutes = map['dailyLimitMinutes'];

    if (packageId is! String || packageId.trim().isEmpty) {
      throw const FormatException('Invalid app limit packageId.');
    }

    if (appName is! String || appName.trim().isEmpty) {
      throw const FormatException('Invalid app limit appName.');
    }

    if (dailyLimitMinutes is! num || dailyLimitMinutes <= 0) {
      throw const FormatException('Invalid app dailyLimitMinutes.');
    }

    final lastWarningRaw = map['lastWarningDate'];
    DateTime? lastWarning;
    if (lastWarningRaw is String) {
      lastWarning = DateTime.tryParse(lastWarningRaw);
    }

    return AppLimit(
      packageId: packageId.trim(),
      appName: appName.trim(),
      dailyLimitMinutes: dailyLimitMinutes.toInt(),
      isEnabled: map['isEnabled'] is bool ? map['isEnabled'] as bool : true,
      lastWarningDate: lastWarning,
    );
  }
}

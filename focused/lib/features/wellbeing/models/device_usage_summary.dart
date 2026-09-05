class DeviceUsageSummary {
  final int activeDaysCount;
  final int avgDailyScreenTimeMinutes;
  final String? mostDistractingApp;
  final int? mostDistractingAppAvgDailyMinutes;
  final int avgDailyFocusMinutes;
  final int totalFocusSessions;
  final int totalFocusMinutes;
  final String? usualFocusTime;

  const DeviceUsageSummary({
    this.activeDaysCount = 0,
    this.avgDailyScreenTimeMinutes = 0,
    this.mostDistractingApp,
    this.mostDistractingAppAvgDailyMinutes,
    this.avgDailyFocusMinutes = 0,
    this.totalFocusSessions = 0,
    this.totalFocusMinutes = 0,
    this.usualFocusTime,
  });

  Map<String, dynamic> toMap() => {
    'activeDaysCount': activeDaysCount,
    'avgDailyScreenTimeMinutes': avgDailyScreenTimeMinutes,
    'mostDistractingApp': mostDistractingApp,
    'mostDistractingAppAvgDailyMinutes': mostDistractingAppAvgDailyMinutes,
    'avgDailyFocusMinutes': avgDailyFocusMinutes,
    'totalFocusSessions': totalFocusSessions,
    'totalFocusMinutes': totalFocusMinutes,
    'usualFocusTime': usualFocusTime,
  };

  factory DeviceUsageSummary.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const DeviceUsageSummary();
    return DeviceUsageSummary(
      activeDaysCount: (map['activeDaysCount'] as num?)?.toInt() ?? 0,
      avgDailyScreenTimeMinutes:
          (map['avgDailyScreenTimeMinutes'] as num?)?.toInt() ?? 0,
      mostDistractingApp: map['mostDistractingApp'] as String?,
      mostDistractingAppAvgDailyMinutes:
          (map['mostDistractingAppAvgDailyMinutes'] as num?)?.toInt(),
      avgDailyFocusMinutes: (map['avgDailyFocusMinutes'] as num?)?.toInt() ?? 0,
      totalFocusSessions: (map['totalFocusSessions'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (map['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      usualFocusTime: map['usualFocusTime'] as String?,
    );
  }
}

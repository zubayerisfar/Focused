import '../models/device_usage_summary.dart';
import '../../focus/services/focus_session_storage_service.dart';
import 'usage_record_storage_service.dart';

class DeviceUsageSummaryService {
  const DeviceUsageSummaryService();

  Future<DeviceUsageSummary> generateSummary({
    required UsageRecordStore? usageRecordStorage,
    required FocusSessionStorageService focusSessionStorage,
  }) async {
    final sessions = focusSessionStorage.loadSessions();
    final totalSessions = sessions.length;
    final totalFocusDuration = sessions.fold<Duration>(
      Duration.zero,
      (acc, s) => acc + s.actualFocusDuration,
    );
    final totalFocusMinutes = totalFocusDuration.inMinutes;

    // Calculate usual focus time of day
    String? usualFocusTime;
    if (sessions.isNotEmpty) {
      var morning = 0; // 05:00 - 12:00
      var afternoon = 0; // 12:00 - 17:00
      var evening = 0; // 17:00 - 22:00
      var night = 0; // 22:00 - 05:00

      for (final session in sessions) {
        final hour = session.startedAt.hour;
        if (hour >= 5 && hour < 12) {
          morning++;
        } else if (hour >= 12 && hour < 17) {
          afternoon++;
        } else if (hour >= 17 && hour < 22) {
          evening++;
        } else {
          night++;
        }
      }

      if (morning >= afternoon && morning >= evening && morning >= night) {
        usualFocusTime = 'Morning (5:00 AM – 12:00 PM)';
      } else if (afternoon >= morning &&
          afternoon >= evening &&
          afternoon >= night) {
        usualFocusTime = 'Afternoon (12:00 PM – 5:00 PM)';
      } else if (evening >= morning &&
          evening >= afternoon &&
          evening >= night) {
        usualFocusTime = 'Evening (5:00 PM – 10:00 PM)';
      } else {
        usualFocusTime = 'Night (10:00 PM – 5:00 AM)';
      }
    }

    var activeDays = 0;
    var avgDailyScreenTimeMinutes = 0;
    String? topApp;
    int? topAppAvgMinutes;
    var avgDailyFocusMinutes = 0;

    final focusDays = sessions
        .map(
          (s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
        )
        .toSet();

    if (usageRecordStorage != null) {
      final days = await usageRecordStorage.loadAllDays();
      final allActiveDays = {
        ...focusDays,
        ...days.map((d) => DateTime(d.day.year, d.day.month, d.day.day)),
      };
      activeDays = allActiveDays.length;

      if (days.isNotEmpty) {
        var totalScreenTimeSeconds = 0;
        final appDurations = <String, int>{};

        for (final day in days) {
          for (final record in day.records) {
            final durationSec = record.duration.inSeconds;
            totalScreenTimeSeconds += durationSec;
            appDurations[record.appId] =
                (appDurations[record.appId] ?? 0) + durationSec;
          }
        }

        avgDailyScreenTimeMinutes = (totalScreenTimeSeconds / days.length / 60)
            .round();

        if (appDurations.isNotEmpty) {
          final sortedApps = appDurations.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final mostUsed = sortedApps.first;
          topApp = mostUsed.key;
          topAppAvgMinutes = (mostUsed.value / days.length / 60).round();
        }
      }
    } else {
      activeDays = focusDays.length;
    }

    if (activeDays > 0) {
      avgDailyFocusMinutes = (totalFocusMinutes / activeDays).round();
    } else if (totalFocusMinutes > 0) {
      avgDailyFocusMinutes = totalFocusMinutes;
    }

    return DeviceUsageSummary(
      activeDaysCount: activeDays,
      avgDailyScreenTimeMinutes: avgDailyScreenTimeMinutes,
      mostDistractingApp: topApp,
      mostDistractingAppAvgDailyMinutes: topAppAvgMinutes,
      avgDailyFocusMinutes: avgDailyFocusMinutes,
      totalFocusSessions: totalSessions,
      totalFocusMinutes: totalFocusMinutes,
      usualFocusTime: usualFocusTime,
    );
  }
}

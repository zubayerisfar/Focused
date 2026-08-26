import 'package:flutter/material.dart';

import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../services/usage_analyzer.dart';

class UsageProvider extends ChangeNotifier {
  final UsageAnalyzer _analyzer = UsageAnalyzer();

  List<AppUsageRecord> _todayRecords = [];
  List<AppUsageRecord> _yesterdayRecords = [];

  DailyUsageSummary? _todaySummary;
  DailyUsageSummary? _yesterdaySummary;

  DailyUsageSummary? get todaySummary => _todaySummary;

  DailyUsageSummary? get yesterdaySummary => _yesterdaySummary;

  List<AppUsageRecord> get todayRecords {
    return List.unmodifiable(_todayRecords);
  }

  List<AppUsageRecord> get yesterdayRecords {
    return List.unmodifiable(_yesterdayRecords);
  }

  double? get todayVsYesterdayPercent {
    final today = _todaySummary?.totalUsage.inSeconds ?? 0;
    final yesterday = _yesterdaySummary?.totalUsage.inSeconds ?? 0;

    if (yesterday == 0) {
      if (today == 0) {
        return 0;
      }

      return null;
    }

    return ((today - yesterday) / yesterday) * 100;
  }

  double? getAppChangePercent(String appName) {
    final todaySeconds = _todaySummary?.appUsage[appName]?.inSeconds ?? 0;

    final yesterdaySeconds =
        _yesterdaySummary?.appUsage[appName]?.inSeconds ?? 0;

    if (yesterdaySeconds == 0) {
      if (todaySeconds == 0) {
        return 0;
      }

      return null;
    }

    return ((todaySeconds - yesterdaySeconds) / yesterdaySeconds) * 100;
  }

  void loadMockData() {
    final now = DateTime.now();

    final yesterday = now.subtract(const Duration(days: 1));

    DateTime at(DateTime date, int hour, int minute) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    // TODAY
    _todayRecords = [
      AppUsageRecord(
        appId: 'com.instagram.android',
        appName: 'Instagram',
        startTime: at(now, 8, 10),
        endTime: at(now, 9, 38),
      ),
      AppUsageRecord(
        appId: 'com.google.android.youtube',
        appName: 'YouTube',
        startTime: at(now, 10, 0),
        endTime: at(now, 10, 58),
      ),
      AppUsageRecord(
        appId: 'com.android.chrome',
        appName: 'Chrome',
        startTime: at(now, 11, 0),
        endTime: at(now, 11, 47),
      ),
      AppUsageRecord(
        appId: 'vscode',
        appName: 'VS Code',
        startTime: at(now, 14, 0),
        endTime: at(now, 14, 50),
      ),
      AppUsageRecord(
        appId: 'com.whatsapp',
        appName: 'WhatsApp',
        startTime: at(now, 15, 30),
        endTime: at(now, 15, 45),
      ),
    ];

    // YESTERDAY
    _yesterdayRecords = [
      AppUsageRecord(
        appId: 'com.instagram.android',
        appName: 'Instagram',
        startTime: at(yesterday, 8, 15),
        endTime: at(yesterday, 9, 25),
      ),
      AppUsageRecord(
        appId: 'com.google.android.youtube',
        appName: 'YouTube',
        startTime: at(yesterday, 10, 0),
        endTime: at(yesterday, 11, 5),
      ),
      AppUsageRecord(
        appId: 'com.android.chrome',
        appName: 'Chrome',
        startTime: at(yesterday, 11, 10),
        endTime: at(yesterday, 12, 5),
      ),
      AppUsageRecord(
        appId: 'vscode',
        appName: 'VS Code',
        startTime: at(yesterday, 14, 0),
        endTime: at(yesterday, 14, 30),
      ),
      AppUsageRecord(
        appId: 'com.whatsapp',
        appName: 'WhatsApp',
        startTime: at(yesterday, 16, 0),
        endTime: at(yesterday, 16, 10),
      ),
    ];

    _todaySummary = _analyzer.buildDailySummary(now, _todayRecords);

    _yesterdaySummary = _analyzer.buildDailySummary(
      yesterday,
      _yesterdayRecords,
    );

    notifyListeners();
  }
}

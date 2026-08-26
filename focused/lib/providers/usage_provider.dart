import 'package:flutter/material.dart';

import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../services/usage_analyzer.dart';

class UsageProvider extends ChangeNotifier {
  final UsageAnalyzer _analyzer = UsageAnalyzer();

  List<AppUsageRecord> _todayRecords = [];

  DailyUsageSummary? _todaySummary;

  List<AppUsageRecord> get todayRecords {
    return List.unmodifiable(_todayRecords);
  }

  DailyUsageSummary? get todaySummary {
    return _todaySummary;
  }

  void loadMockData() {
    final now = DateTime.now();

    DateTime todayAt(int hour, int minute) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    _todayRecords = [
      AppUsageRecord(
        appId: 'com.instagram.android',
        appName: 'Instagram',
        startTime: todayAt(8, 10),
        endTime: todayAt(9, 38),
      ),

      AppUsageRecord(
        appId: 'com.google.android.youtube',
        appName: 'YouTube',
        startTime: todayAt(10, 0),
        endTime: todayAt(10, 58),
      ),

      AppUsageRecord(
        appId: 'com.android.chrome',
        appName: 'Chrome',
        startTime: todayAt(11, 0),
        endTime: todayAt(11, 47),
      ),

      AppUsageRecord(
        appId: 'vscode',
        appName: 'VS Code',
        startTime: todayAt(14, 0),
        endTime: todayAt(14, 50),
      ),

      AppUsageRecord(
        appId: 'com.whatsapp',
        appName: 'WhatsApp',
        startTime: todayAt(15, 30),
        endTime: todayAt(15, 45),
      ),
    ];

    _todaySummary = _analyzer.buildDailySummary(now, _todayRecords);

    notifyListeners();
  }
}

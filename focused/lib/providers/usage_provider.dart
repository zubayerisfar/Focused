import 'package:flutter/material.dart';

import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';

import '../models/app_category.dart';
import '../models/focus_analysis_result.dart';
import '../services/focus_interruption_analyzer.dart';

import '../models/focus_session.dart';

class UsageProvider extends ChangeNotifier {
  void analyzeCompletedFocusSession(FocusSession session) {
    _focusAnalysisResult = _focusInterruptionAnalyzer.analyzeSession(
      session: session,
      usageRecords: _todayRecords,
      appCategories: _appCategories,
    );

    notifyListeners();
  }

  final FocusInterruptionAnalyzer _focusInterruptionAnalyzer =
      FocusInterruptionAnalyzer();

  final Map<String, AppCategory> _appCategories = {
    'Instagram': AppCategory.distracting,
    'YouTube': AppCategory.distracting,
    'WhatsApp': AppCategory.distracting,

    'VS Code': AppCategory.productive,

    'Chrome': AppCategory.neutral,
  };

  FocusAnalysisResult? _focusAnalysisResult;

  FocusAnalysisResult? get focusAnalysisResult {
    return _focusAnalysisResult;
  }

  AppCategory getAppCategory(String appName) {
    return _appCategories[appName] ?? AppCategory.neutral;
  }

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


}

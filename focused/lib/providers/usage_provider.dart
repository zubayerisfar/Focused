import 'package:flutter/material.dart';

import '../models/app_category.dart';
import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../models/focus_analysis_result.dart';
import '../models/focus_session.dart';
import '../models/usage_access_status.dart';
import '../services/android_usage_stats_service.dart';
import '../services/focus_interruption_analyzer.dart';
import '../services/usage_analyzer.dart';
import '../services/usage_record_storage_service.dart';
import '../services/usage_stats_service.dart';

class UsageProvider extends ChangeNotifier {
  UsageProvider({
    UsageStatsService? usageStatsService,
    UsageRecordStore? storageService,
    UsageAnalyzer? usageAnalyzer,
    FocusInterruptionAnalyzer? focusInterruptionAnalyzer,
  })  : _usageStatsService = usageStatsService ?? AndroidUsageStatsService(),
        _storageService = storageService,
        _usageAnalyzer = usageAnalyzer ?? UsageAnalyzer(),
        _focusInterruptionAnalyzer =
            focusInterruptionAnalyzer ?? FocusInterruptionAnalyzer();

  final UsageStatsService _usageStatsService;
  final UsageRecordStore? _storageService;
  final UsageAnalyzer _usageAnalyzer;
  final FocusInterruptionAnalyzer _focusInterruptionAnalyzer;

  // Package ids are the stable key for real Android data. A few legacy labels
  // are retained as aliases so existing analyzer tests/data remain meaningful.
  // Unknown apps stay neutral until a later user-classification stage.
  final Map<String, AppCategory> _appCategories = {
    'com.instagram.android': AppCategory.distracting,
    'Instagram': AppCategory.distracting,
    'com.google.android.youtube': AppCategory.distracting,
    'YouTube': AppCategory.distracting,
    'com.whatsapp': AppCategory.distracting,
    'WhatsApp': AppCategory.distracting,
    'com.facebook.katana': AppCategory.distracting,
    'com.zhiliaoapp.musically': AppCategory.distracting,
    'com.reddit.frontpage': AppCategory.distracting,
    'com.snapchat.android': AppCategory.distracting,
    'org.telegram.messenger': AppCategory.distracting,
    'com.android.chrome': AppCategory.neutral,
    'Chrome': AppCategory.neutral,
  };

  UsageAccessStatus _accessStatus = UsageAccessStatus.unknown;
  bool _isRefreshing = false;
  bool _isAnalyzingFocus = false;
  String? _lastError;
  String? _analysisUnavailableReason;
  DateTime? _lastUpdatedAt;

  List<AppUsageRecord> _todayRecords = [];
  List<AppUsageRecord> _yesterdayRecords = [];

  DailyUsageSummary? _todaySummary;
  DailyUsageSummary? _yesterdaySummary;
  FocusAnalysisResult? _focusAnalysisResult;

  Future<void>? _permissionRefreshInFlight;
  Future<void>? _usageRefreshInFlight;

  UsageAccessStatus get accessStatus => _accessStatus;
  bool get isRefreshing => _isRefreshing;
  bool get isAnalyzingFocus => _isAnalyzingFocus;
  bool get hasUsageAccess => _accessStatus == UsageAccessStatus.granted;
  bool get isSupported => _usageStatsService.isSupported;
  String? get lastError => _lastError;
  String? get analysisUnavailableReason => _analysisUnavailableReason;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DailyUsageSummary? get todaySummary => _todaySummary;
  DailyUsageSummary? get yesterdaySummary => _yesterdaySummary;
  FocusAnalysisResult? get focusAnalysisResult => _focusAnalysisResult;

  List<AppUsageRecord> get todayRecords => List.unmodifiable(_todayRecords);
  List<AppUsageRecord> get yesterdayRecords =>
      List.unmodifiable(_yesterdayRecords);

  AppCategory getAppCategory(String appIdOrName) {
    return _appCategories[appIdOrName] ?? AppCategory.neutral;
  }

  /// Loads the most recent locally cached snapshots without touching Android's
  /// UsageStats API. This keeps app startup fast and preserves offline history.
  Future<void> loadStoredUsage({DateTime? now}) async {
    final store = _storageService;
    if (store == null) {
      return;
    }

    final effectiveNow = now ?? DateTime.now();
    final today = _startOfDay(effectiveNow);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final todaySnapshot = await store.loadDay(today);
    final yesterdaySnapshot = await store.loadDay(yesterday);

    if (todaySnapshot != null) {
      _todayRecords = List.of(todaySnapshot.records);
      _todaySummary = _usageAnalyzer.buildDailySummary(
        today,
        _todayRecords,
      );
      _lastUpdatedAt = todaySnapshot.updatedAt;
    }

    if (yesterdaySnapshot != null) {
      _yesterdayRecords = List.of(yesterdaySnapshot.records);
      _yesterdaySummary = _usageAnalyzer.buildDailySummary(
        yesterday,
        _yesterdayRecords,
      );
    }

    notifyListeners();
  }

  Future<void> refreshPermissionAndUsage({
    DateTime? now,
    bool force = false,
  }) {
    final inFlight = _permissionRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshPermissionAndUsageInternal(
      now: now,
      force: force,
    );

    _permissionRefreshInFlight = future;
    return future.whenComplete(() {
      _permissionRefreshInFlight = null;
    });
  }

  Future<void> _refreshPermissionAndUsageInternal({
    DateTime? now,
    required bool force,
  }) async {
    if (!_usageStatsService.isSupported) {
      _accessStatus = UsageAccessStatus.unsupported;
      _lastError = null;
      notifyListeners();
      return;
    }

    _accessStatus = UsageAccessStatus.checking;
    _lastError = null;
    notifyListeners();

    try {
      final granted = await _usageStatsService.hasUsageAccess();

      if (!granted) {
        _accessStatus = UsageAccessStatus.denied;
        notifyListeners();
        return;
      }

      _accessStatus = UsageAccessStatus.granted;
      notifyListeners();

      await refreshUsage(now: now, force: force);
    } catch (error) {
      _accessStatus = UsageAccessStatus.error;
      _lastError = 'Could not check Android Usage Access: $error';
      notifyListeners();
    }
  }

  Future<void> requestUsageAccess() async {
    if (!_usageStatsService.isSupported) {
      _accessStatus = UsageAccessStatus.unsupported;
      notifyListeners();
      return;
    }

    _accessStatus = UsageAccessStatus.checking;
    _lastError = null;
    notifyListeners();

    try {
      await _usageStatsService.requestUsageAccess();
      // Android does not return a permission result here. The app lifecycle
      // re-checks access when the user returns from Settings.
    } catch (error) {
      _accessStatus = UsageAccessStatus.error;
      _lastError = 'Could not open Usage Access settings: $error';
      notifyListeners();
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _usageStatsService.openUsageAccessSettings();
    } catch (error) {
      _lastError = 'Could not open Usage Access settings: $error';
      notifyListeners();
    }
  }

  Future<void> refreshUsage({
    DateTime? now,
    bool force = false,
  }) {
    final inFlight = _usageRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshUsageInternal(now: now, force: force);
    _usageRefreshInFlight = future;
    return future.whenComplete(() {
      _usageRefreshInFlight = null;
    });
  }

  Future<void> _refreshUsageInternal({
    DateTime? now,
    required bool force,
  }) async {
    if (!_usageStatsService.isSupported) {
      _accessStatus = UsageAccessStatus.unsupported;
      notifyListeners();
      return;
    }

    final effectiveNow = now ?? DateTime.now();

    if (!force &&
        _lastUpdatedAt != null &&
        _sameDate(_lastUpdatedAt!, effectiveNow)) {
      final sinceLastRefresh = effectiveNow.difference(_lastUpdatedAt!);
      if (!sinceLastRefresh.isNegative &&
          sinceLastRefresh < const Duration(seconds: 20)) {
        return;
      }
    }

    if (_accessStatus != UsageAccessStatus.granted) {
      final granted = await _usageStatsService.hasUsageAccess();
      if (!granted) {
        _accessStatus = UsageAccessStatus.denied;
        notifyListeners();
        return;
      }
      _accessStatus = UsageAccessStatus.granted;
    }

    _isRefreshing = true;
    _lastError = null;
    notifyListeners();

    final today = _startOfDay(effectiveNow);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final store = _storageService;
    final errors = <String>[];

    try {
      final todayRecords = await _usageStatsService.queryUsageRecords(
        today,
        effectiveNow,
      );

      _todayRecords = List.of(todayRecords);
      _todaySummary = _usageAnalyzer.buildDailySummary(today, _todayRecords);
      _lastUpdatedAt = effectiveNow;

      if (store != null) {
        await store.saveDay(
          today,
          _todayRecords,
          updatedAt: effectiveNow,
        );
      }
    } catch (error) {
      errors.add('Today: $error');
    }

    try {
      final yesterdayRecords = await _usageStatsService.queryUsageRecords(
        yesterday,
        today,
      );

      _yesterdayRecords = List.of(yesterdayRecords);
      _yesterdaySummary = _usageAnalyzer.buildDailySummary(
        yesterday,
        _yesterdayRecords,
      );

      if (store != null) {
        await store.saveDay(
          yesterday,
          _yesterdayRecords,
          updatedAt: effectiveNow,
        );
      }
    } catch (error) {
      errors.add('Yesterday: $error');
    }

    _isRefreshing = false;

    if (errors.isNotEmpty) {
      _lastError = 'Usage refresh was incomplete. ${errors.join(' ')}';
    }

    notifyListeners();
  }

  Future<void> analyzeCompletedFocusSession(FocusSession session) async {
    _focusAnalysisResult = null;
    _analysisUnavailableReason = null;
    _isAnalyzingFocus = true;
    notifyListeners();

    try {
      if (!_usageStatsService.isSupported) {
        _analysisUnavailableReason =
            'Real app-usage analysis is available on Android only.';
        return;
      }

      final granted = await _usageStatsService.hasUsageAccess();
      if (!granted) {
        _accessStatus = UsageAccessStatus.denied;
        _analysisUnavailableReason =
            'Grant Android Usage Access to measure app interruptions.';
        return;
      }

      _accessStatus = UsageAccessStatus.granted;

      // Query exactly the session window so the result cannot accidentally use
      // stale or unrelated daily data.
      final records = await _usageStatsService.queryUsageRecords(
        session.startedAt,
        session.endedAt,
      );

      _focusAnalysisResult = _focusInterruptionAnalyzer.analyzeSession(
        session: session,
        usageRecords: records,
        appCategories: _appCategories,
      );
    } catch (error) {
      _analysisUnavailableReason =
          'Focused could not read app usage for this session: $error';
    } finally {
      _isAnalyzingFocus = false;
      notifyListeners();
    }
  }

  double? get todayVsYesterdayPercent {
    final today = _todaySummary?.totalUsage.inSeconds;
    final yesterday = _yesterdaySummary?.totalUsage.inSeconds;

    if (today == null || yesterday == null) {
      return null;
    }

    if (yesterday == 0) {
      return today == 0 ? 0 : null;
    }

    return ((today - yesterday) / yesterday) * 100;
  }

  double? getAppChangePercent(String appName) {
    if (_todaySummary == null || _yesterdaySummary == null) {
      return null;
    }

    final todaySeconds = _todaySummary!.appUsage[appName]?.inSeconds ?? 0;
    final yesterdaySeconds =
        _yesterdaySummary!.appUsage[appName]?.inSeconds ?? 0;

    if (yesterdaySeconds == 0) {
      return todaySeconds == 0 ? 0 : null;
    }

    return ((todaySeconds - yesterdaySeconds) / yesterdaySeconds) * 100;
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

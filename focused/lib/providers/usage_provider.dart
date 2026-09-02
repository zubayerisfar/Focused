import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_category.dart';
import '../models/app_open_event.dart';
import '../models/app_metadata.dart';
import '../models/app_usage_app_entry.dart';
import '../models/app_usage_history_point.dart';
import '../models/daily_usage_metrics.dart';
import '../models/app_usage_record.dart';
import '../models/daily_usage_summary.dart';
import '../models/focus_analysis_result.dart';
import '../models/focus_analysis_coverage.dart';
import '../models/focus_session.dart';
import '../models/notification_event.dart';
import '../models/usage_access_status.dart';
import '../models/usage_data_coverage.dart';
import '../models/usage_data_provenance.dart';
import '../services/android_usage_stats_service.dart';
import '../services/app_metadata_platform_service.dart';
import '../services/app_metadata_storage_service.dart';
import '../services/app_category_storage_service.dart';
import '../services/focus_analysis_storage_service.dart';
import '../services/focus_interruption_analyzer.dart';
import '../services/focus_guard_service.dart';
import '../services/notification_access_service.dart';
import '../services/usage_analyzer.dart';
import '../services/usage_record_storage_service.dart';
import '../services/usage_stats_service.dart';

class UsageProvider extends ChangeNotifier {
  UsageProvider({
    UsageStatsService? usageStatsService,
    UsageRecordStore? storageService,
    AppCategoryStore? categoryStorageService,
    FocusAnalysisStore? focusAnalysisStorageService,
    AppMetadataPlatformService? appMetadataService,
    AppMetadataStore? appMetadataStorageService,
    UsageAnalyzer? usageAnalyzer,
    FocusInterruptionAnalyzer? focusInterruptionAnalyzer,
    FocusGuardController? focusGuardController,
    NotificationAccessService? notificationAccessService,
    DateTime? historyStartedAt,
  }) : _usageStatsService = usageStatsService ?? AndroidUsageStatsService(),
       _storageService = storageService,
       _categoryStorageService = categoryStorageService,
       _focusAnalysisStorageService = focusAnalysisStorageService,
       _appMetadataService = appMetadataService ?? AndroidAppMetadataService(),
       _appMetadataStorageService = appMetadataStorageService,
       _usageAnalyzer = usageAnalyzer ?? UsageAnalyzer(),
       _focusInterruptionAnalyzer =
           focusInterruptionAnalyzer ?? FocusInterruptionAnalyzer(),
       _focusGuardController =
           focusGuardController ?? const NoopFocusGuardController(),
       _notificationAccessService =
           notificationAccessService ?? NotificationAccessService(),
       _historyStartedAt = historyStartedAt?.toLocal();

  final UsageStatsService _usageStatsService;
  final UsageRecordStore? _storageService;
  final AppCategoryStore? _categoryStorageService;
  final FocusAnalysisStore? _focusAnalysisStorageService;
  final AppMetadataPlatformService _appMetadataService;
  final AppMetadataStore? _appMetadataStorageService;
  final UsageAnalyzer _usageAnalyzer;
  final FocusInterruptionAnalyzer _focusInterruptionAnalyzer;
  final FocusGuardController _focusGuardController;
  final NotificationAccessService _notificationAccessService;
  final DateTime? _historyStartedAt;

  void Function(Map<String, Duration> todayUsageByPackage)? onUsageUpdated;

  // Package ids are the stable key for real Android data. A few legacy labels
  // are retained as aliases so existing analyzer tests/data remain meaningful.
  // Unknown apps stay neutral until a later user-classification stage.
  final Map<String, AppCategory> _defaultAppCategories = {
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

  final Map<String, AppCategory> _userAppCategories = {};
  final Map<String, AppMetadata> _appMetadataById = {};
  final Set<String> _metadataLoadsInFlight = {};

  static const Duration _metadataRefreshAge = Duration(days: 7);
  static const Duration _metadataMissingRetryAge = Duration(days: 1);

  UsageAccessStatus _accessStatus = UsageAccessStatus.unknown;
  bool _isRefreshing = false;
  bool _isAnalyzingFocus = false;
  String? _lastError;
  String? _appMetadataError;
  String? _analysisUnavailableReason;
  DateTime? _lastUpdatedAt;

  List<AppUsageRecord> _todayRecords = [];
  List<AppUsageRecord> _yesterdayRecords = [];
  UsageDataProvenance _todayProvenance = UsageDataProvenance.missing;
  UsageDataProvenance _yesterdayProvenance = UsageDataProvenance.missing;

  final Map<String, FocusAnalysisResult> _focusAnalysesBySessionId = {};

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
  String? get appMetadataError => _appMetadataError;
  String? get analysisUnavailableReason => _analysisUnavailableReason;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  DailyUsageSummary? get todaySummary => _todaySummary;
  DailyUsageSummary? get yesterdaySummary => _yesterdaySummary;
  FocusAnalysisResult? get focusAnalysisResult => _focusAnalysisResult;
  UsageDataProvenance get todayProvenance => _todayProvenance;
  UsageDataProvenance get yesterdayProvenance => _yesterdayProvenance;
  DateTime? get usageHistoryStartDay =>
      _historyStartedAt == null ? null : _startOfDay(_historyStartedAt!);

  Map<String, FocusAnalysisResult> get storedFocusAnalyses =>
      Map<String, FocusAnalysisResult>.unmodifiable(_focusAnalysesBySessionId);

  List<AppUsageRecord> get todayRecords => List.unmodifiable(_todayRecords);
  List<AppUsageRecord> get yesterdayRecords =>
      List.unmodifiable(_yesterdayRecords);

  Map<String, AppMetadata> get appMetadata =>
      Map<String, AppMetadata>.unmodifiable(_appMetadataById);

  AppMetadata? getAppMetadata(String appId) {
    return _appMetadataById[appId];
  }

  String resolveDisplayName(String appId, {String? fallback}) {
    final metadata = _appMetadataById[appId];
    final nativeName = metadata?.displayName.trim();

    if (nativeName != null && nativeName.isNotEmpty && nativeName != appId) {
      return nativeName;
    }

    final resolved = resolveAppName(appId, fallback: fallback);
    if (resolved.trim().isNotEmpty) {
      return resolved;
    }

    return appId;
  }

  Future<void> loadStoredAppMetadata() async {
    final store = _appMetadataStorageService;
    if (store == null) {
      return;
    }

    final stored = await store.loadAll();
    _appMetadataById
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  Future<void> ensureAppMetadata(String appId, {bool force = false}) {
    return ensureAppMetadataForPackages([appId], force: force);
  }

  Future<void> ensureAppMetadataForPackages(
    Iterable<String> packageNames, {
    bool force = false,
  }) async {
    if (!_appMetadataService.isSupported) {
      return;
    }

    final now = DateTime.now();
    final requested = packageNames
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    final candidates = requested
        .where((packageName) {
          if (_metadataLoadsInFlight.contains(packageName)) {
            return false;
          }

          if (force) {
            return true;
          }

          final cached = _appMetadataById[packageName];
          if (cached == null) {
            return true;
          }

          final age = now.difference(cached.updatedAt);
          if (age.isNegative) {
            return true;
          }

          final refreshAge = cached.hasIcon
              ? _metadataRefreshAge
              : _metadataMissingRetryAge;
          return age >= refreshAge;
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      return;
    }

    _metadataLoadsInFlight.addAll(candidates);

    try {
      final resolved = <AppMetadata>[];
      const batchSize = 80;
      for (var offset = 0; offset < candidates.length; offset += batchSize) {
        final end = (offset + batchSize).clamp(0, candidates.length).toInt();
        resolved.addAll(
          await _appMetadataService.loadMetadata(
            candidates.sublist(offset, end),
          ),
        );
      }

      _appMetadataError = null;
      final byPackage = {for (final item in resolved) item.packageName: item};

      final updates = <AppMetadata>[];
      for (final packageName in candidates) {
        final existing = _appMetadataById[packageName];
        final resolvedItem = byPackage[packageName];

        final item = resolvedItem == null
            ? (existing?.copyWith(updatedAt: now) ??
                  AppMetadata(
                    packageName: packageName,
                    displayName: packageName,
                    iconBytes: null,
                    isInstalled: false,
                    updatedAt: now,
                  ))
            : AppMetadata(
                packageName: packageName,
                displayName:
                    resolvedItem.displayName == packageName &&
                        existing != null &&
                        existing.displayName != packageName
                    ? existing.displayName
                    : resolvedItem.displayName,
                iconBytes: resolvedItem.iconBytes ?? existing?.iconBytes,
                isInstalled: resolvedItem.isInstalled,
                updatedAt: resolvedItem.updatedAt,
              );

        _appMetadataById[packageName] = item;
        updates.add(item);
      }

      final store = _appMetadataStorageService;
      if (store != null) {
        try {
          await store.saveAll(updates);
        } catch (error) {
          _appMetadataError =
              'App icons were loaded but could not be cached: $error';
        }
      }

      notifyListeners();
    } catch (error) {
      _appMetadataError = 'Could not load Android app icons: $error';
      notifyListeners();
    } finally {
      _metadataLoadsInFlight.removeAll(candidates);
    }
  }

  void _ensureMetadataForRecords(Iterable<AppUsageRecord> records) {
    final packages = records.map((record) => record.appId).toSet();
    if (packages.isEmpty) {
      return;
    }

    unawaited(ensureAppMetadataForPackages(packages));
  }

  AppCategory getAppCategory(String appIdOrName) {
    return _userAppCategories[appIdOrName] ??
        _defaultAppCategories[appIdOrName] ??
        AppCategory.neutral;
  }

  Map<String, AppCategory> get effectiveAppCategories {
    return Map<String, AppCategory>.unmodifiable({
      ..._defaultAppCategories,
      ..._userAppCategories,
    });
  }

  Set<String> get productivePackageIds {
    return Set<String>.unmodifiable(
      effectiveAppCategories.entries
          .where(
            (entry) =>
                entry.value == AppCategory.productive &&
                _looksLikeAndroidPackage(entry.key),
          )
          .map((entry) => entry.key),
    );
  }

  Future<void> loadStoredCategories() async {
    final store = _categoryStorageService;
    if (store == null) {
      return;
    }

    final stored = await store.loadAll();
    _userAppCategories
      ..clear()
      ..addAll(stored);
    notifyListeners();

    await _cacheFocusGuardAllowedPackages();
  }

  Future<void> setAppCategory(String appId, AppCategory category) async {
    final normalized = appId.trim();
    if (normalized.isEmpty) {
      return;
    }

    final previous = _userAppCategories[normalized];
    _userAppCategories[normalized] = category;
    notifyListeners();
    unawaited(_updateFocusGuardAllowedPackages());

    final store = _categoryStorageService;
    if (store == null) {
      return;
    }

    try {
      await store.saveCategory(normalized, category);
    } catch (error) {
      if (previous == null) {
        _userAppCategories.remove(normalized);
      } else {
        _userAppCategories[normalized] = previous;
      }
      _lastError = 'Could not save the app category: $error';
      notifyListeners();
      unawaited(_updateFocusGuardAllowedPackages());
      rethrow;
    }
  }

  Future<void> syncFocusGuardAllowedPackages() {
    return _updateFocusGuardAllowedPackages();
  }

  Future<void> _cacheFocusGuardAllowedPackages() async {
    try {
      await _focusGuardController.cacheFocusGuardAllowedPackages(
        productivePackageIds,
      );
    } catch (error) {
      debugPrint('Could not cache Focus Guard packages: $error');
    }
  }

  Future<void> _updateFocusGuardAllowedPackages() async {
    try {
      await _focusGuardController.updateFocusGuardAllowedPackages(
        productivePackageIds,
      );
    } catch (error) {
      debugPrint('Could not update Focus Guard packages: $error');
    }
  }

  Future<void> loadStoredFocusAnalyses() async {
    final store = _focusAnalysisStorageService;
    if (store == null) {
      return;
    }

    _focusAnalysesBySessionId.clear();
    for (final item in store.loadAll()) {
      _focusAnalysesBySessionId[item.sessionId] = item.analysis;
    }
    notifyListeners();
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
      final records = _applyHistoryBoundary(
        todaySnapshot.day,
        todaySnapshot.records,
      );
      if (records.isNotEmpty) {
        _todayRecords = List.of(records);
        _todaySummary = _usageAnalyzer.buildDailySummary(today, _todayRecords);
        _lastUpdatedAt = todaySnapshot.updatedAt;
        _todayProvenance = UsageDataProvenance.focusedStorage;
      }
    }

    if (yesterdaySnapshot != null && !_isBeforeHistoryStart(yesterday)) {
      final records = _applyHistoryBoundary(
        yesterdaySnapshot.day,
        yesterdaySnapshot.records,
      );
      if (records.isNotEmpty) {
        _yesterdayRecords = List.of(records);
        _yesterdaySummary = _usageAnalyzer.buildDailySummary(
          yesterday,
          _yesterdayRecords,
        );
        _yesterdayProvenance = UsageDataProvenance.focusedStorage;
      }
    }

    _ensureMetadataForRecords([..._todayRecords, ..._yesterdayRecords]);
    _dispatchUsageUpdate();
    notifyListeners();
  }

  Future<void> refreshPermissionAndUsage({DateTime? now, bool force = false}) {
    final inFlight = _permissionRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshPermissionAndUsageInternal(now: now, force: force);

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

  Future<void> refreshUsage({DateTime? now, bool force = false}) {
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
        _effectiveQueryStart(today),
        effectiveNow,
      );

      _todayRecords = List.of(todayRecords);
      _todaySummary = _usageAnalyzer.buildDailySummary(today, _todayRecords);
      _lastUpdatedAt = effectiveNow;
      _todayProvenance = UsageDataProvenance.liveAndroid;

      if (store != null) {
        if (_todayRecords.isEmpty) {
          await store.deleteDay(today);
        } else {
          await store.saveDay(today, _todayRecords, updatedAt: effectiveNow);
        }
      }
    } catch (error) {
      errors.add('Today: $error');
    }

    if (_isBeforeHistoryStart(yesterday)) {
      _yesterdayRecords = const <AppUsageRecord>[];
      _yesterdaySummary = null;
      _yesterdayProvenance = UsageDataProvenance.missing;
      if (store != null) {
        await store.deleteDay(yesterday);
      }
    } else {
      try {
        final yesterdayRecords = await _usageStatsService.queryUsageRecords(
          _effectiveQueryStart(yesterday),
          today,
        );

        _yesterdayRecords = List.of(yesterdayRecords);
        if (_yesterdayRecords.isEmpty) {
          _yesterdaySummary = null;
          _yesterdayProvenance = UsageDataProvenance.missing;
          if (store != null) {
            await store.deleteDay(yesterday);
          }
        } else {
          _yesterdaySummary = _usageAnalyzer.buildDailySummary(
            yesterday,
            _yesterdayRecords,
          );
          _yesterdayProvenance = UsageDataProvenance.androidHistory;

          if (store != null) {
            await store.saveDay(
              yesterday,
              _yesterdayRecords,
              updatedAt: effectiveNow,
            );
          }
        }
      } catch (error) {
        errors.add('Yesterday: $error');
      }
    }

    _ensureMetadataForRecords([..._todayRecords, ..._yesterdayRecords]);

    _isRefreshing = false;

    if (errors.isNotEmpty) {
      _lastError = 'Usage refresh was incomplete. ${errors.join(' ')}';
    }

    _dispatchUsageUpdate();
    notifyListeners();
  }

  void _dispatchUsageUpdate() {
    final summary = _todaySummary;
    if (summary == null || onUsageUpdated == null) return;
    onUsageUpdated!(summary.appUsage);
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
      _ensureMetadataForRecords(records);

      final analysis = _focusInterruptionAnalyzer.analyzeSession(
        session: session,
        usageRecords: records,
        appCategories: effectiveAppCategories,
      );

      _focusAnalysisResult = analysis;
      _focusAnalysesBySessionId[session.id] = analysis;

      final analysisStore = _focusAnalysisStorageService;
      if (analysisStore != null) {
        try {
          await analysisStore.saveAnalysis(session.id, analysis);
        } catch (storageError) {
          _lastError =
              'Focus analysis was calculated but could not be saved: $storageError';
        }
      }
    } catch (error) {
      _analysisUnavailableReason =
          'Focused could not read app usage for this session: $error';
    } finally {
      _isAnalyzingFocus = false;
      notifyListeners();
    }
  }

  double? get todayVsYesterdayPercent {
    final todaySummary = _todaySummary;
    final yesterdaySummary = _comparableYesterdaySummary();

    if (todaySummary == null || yesterdaySummary == null) {
      return null;
    }

    final today = todaySummary.totalUsage.inSeconds;
    final yesterday = yesterdaySummary.totalUsage.inSeconds;

    if (yesterday == 0) {
      return today == 0 ? 0 : null;
    }

    return ((today - yesterday) / yesterday) * 100;
  }

  double? getAppChangePercent(String appName) {
    final todaySummary = _todaySummary;
    final yesterdaySummary = _comparableYesterdaySummary();
    if (todaySummary == null || yesterdaySummary == null) {
      return null;
    }

    final todaySeconds = todaySummary.appUsage[appName]?.inSeconds ?? 0;
    final yesterdaySeconds = yesterdaySummary.appUsage[appName]?.inSeconds ?? 0;

    if (yesterdaySeconds == 0) {
      return todaySeconds == 0 ? 0 : null;
    }

    return ((todaySeconds - yesterdaySeconds) / yesterdaySeconds) * 100;
  }

  /// The most-used apps for today, ordered by attributed app time.
  ///
  /// DailyUsageSummary already unions duplicate intervals for the same app, so
  /// this list is safe to use for ranking and display. Global screen time is
  /// still represented by [DailyUsageSummary.totalUsage].
  List<MapEntry<String, Duration>> topAppsToday({int limit = 5}) {
    if (limit <= 0 || _todaySummary == null) {
      return const <MapEntry<String, Duration>>[];
    }

    final entries = _todaySummary!.appUsage.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));

    return List<MapEntry<String, Duration>>.unmodifiable(entries.take(limit));
  }

  /// Unique usage time for one app category today.
  ///
  /// We filter raw normalized records and run them back through UsageAnalyzer
  /// so overlapping apps in the same category cannot inflate the result.
  Duration usageForCategoryToday(AppCategory category) {
    final summary = _todaySummary;
    if (summary == null || _todayRecords.isEmpty) {
      return Duration.zero;
    }

    final filtered = _todayRecords.where((record) {
      final userByPackage = _userAppCategories[record.appId];
      final userByName = _userAppCategories[record.appName];
      final defaultByPackage = _defaultAppCategories[record.appId];
      final defaultByName = _defaultAppCategories[record.appName];

      final resolved =
          userByPackage ??
          userByName ??
          defaultByPackage ??
          defaultByName ??
          AppCategory.neutral;

      return resolved == category;
    }).toList();

    if (filtered.isEmpty) {
      return Duration.zero;
    }

    return _usageAnalyzer.buildDailySummary(summary.date, filtered).totalUsage;
  }

  String? get topDistractingAppToday {
    final entries = topAppEntriesToday(limit: _todayRecords.length);

    for (final entry in entries) {
      final resolved =
          _userAppCategories[entry.appId] ??
          _userAppCategories[entry.appName] ??
          _defaultAppCategories[entry.appId] ??
          _defaultAppCategories[entry.appName] ??
          AppCategory.neutral;

      if (resolved == AppCategory.distracting) {
        return entry.appName;
      }
    }

    return null;
  }

  String? resolveAppIdForName(String appName) {
    for (final record in _todayRecords) {
      if (record.appName == appName) {
        return record.appId;
      }
    }

    for (final record in _yesterdayRecords) {
      if (record.appName == appName) {
        return record.appId;
      }
    }

    return null;
  }

  String resolveAppName(String appId, {String? fallback}) {
    for (final record in _todayRecords) {
      if (record.appId == appId) {
        return record.appName;
      }
    }

    for (final record in _yesterdayRecords) {
      if (record.appId == appId) {
        return record.appName;
      }
    }

    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }

    return appId;
  }

  List<AppUsageAppEntry> topAppEntriesToday({int limit = 5}) {
    if (limit <= 0 || _todayRecords.isEmpty || _todaySummary == null) {
      return const <AppUsageAppEntry>[];
    }

    final byId = <String, List<AppUsageRecord>>{};
    final names = <String, String>{};

    for (final record in _todayRecords) {
      byId.putIfAbsent(record.appId, () => []).add(record);
      names[record.appId] = record.appName;
    }

    final entries = <AppUsageAppEntry>[];

    for (final item in byId.entries) {
      final summary = _usageAnalyzer.buildDailySummary(
        _todaySummary!.date,
        item.value,
      );

      final metadata = _appMetadataById[item.key];
      entries.add(
        AppUsageAppEntry(
          appId: item.key,
          appName: resolveDisplayName(
            item.key,
            fallback: names[item.key] ?? item.key,
          ),
          duration: summary.totalUsage,
          iconBytes: metadata?.iconBytes,
        ),
      );
    }

    entries.sort((a, b) => b.duration.compareTo(a.duration));

    return List<AppUsageAppEntry>.unmodifiable(entries.take(limit));
  }

  double? getAppChangePercentById(String appId) {
    if (_todaySummary == null || _yesterdaySummary == null) {
      return null;
    }

    final todayUsage = _usageForAppInRecords(
      appId,
      _todaySummary!.date,
      _todayRecords,
    );
    final comparableYesterdayRecords = _comparableYesterdayRecords();
    if (comparableYesterdayRecords == null) {
      return null;
    }

    final yesterdayUsage = _usageForAppInRecords(
      appId,
      _yesterdaySummary!.date,
      comparableYesterdayRecords,
    );

    if (yesterdayUsage.inSeconds == 0) {
      return todayUsage.inSeconds == 0 ? 0 : null;
    }

    return ((todayUsage.inSeconds - yesterdayUsage.inSeconds) /
            yesterdayUsage.inSeconds) *
        100;
  }

  Future<List<AppUsageHistoryPoint>> loadAppUsageHistory(
    String appId, {
    int days = 7,
    DateTime? endDay,
    bool backfillRecentMissingDays = true,
  }) async {
    if (days <= 0) {
      return const <AppUsageHistoryPoint>[];
    }

    unawaited(ensureAppMetadata(appId));

    final now = DateTime.now();
    final normalizedEnd = _startOfDay(endDay ?? now);
    final start = DateTime(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day - (days - 1),
    );

    final result = <AppUsageHistoryPoint>[];

    for (var index = 0; index < days; index++) {
      final day = DateTime(start.year, start.month, start.day + index);
      if (_isBeforeHistoryStart(day)) {
        continue;
      }

      final resolved = await _resolveUsageDay(
        day,
        now: now,
        backfillRecentMissingDays: backfillRecentMissingDays,
      );

      if (resolved == null) {
        result.add(
          AppUsageHistoryPoint(
            day: day,
            usage: Duration.zero,
            measured: false,
            completeDay: false,
            provenance: UsageDataProvenance.missing,
          ),
        );
        continue;
      }

      result.add(
        AppUsageHistoryPoint(
          day: day,
          usage: _usageForAppInRecords(appId, day, resolved.snapshot.records),
          measured: true,
          completeDay: resolved.completeDay,
          provenance: resolved.provenance,
        ),
      );
    }

    return List<AppUsageHistoryPoint>.unmodifiable(result);
  }

  Future<List<AppOpenEvent>> loadAppOpenEvents({
    required DateTime start,
    required DateTime end,
    String? appId,
  }) async {
    if (!_usageStatsService.isSupported || !end.isAfter(start)) {
      return const <AppOpenEvent>[];
    }

    final historyStart = _historyStartedAt?.toLocal();
    final effectiveStart = historyStart != null && historyStart.isAfter(start)
        ? historyStart
        : start;
    if (!end.isAfter(effectiveStart)) {
      return const <AppOpenEvent>[];
    }

    final granted = await _usageStatsService.hasUsageAccess();
    if (!granted) return const <AppOpenEvent>[];

    final events = await _usageStatsService.queryAppOpenEvents(
      effectiveStart,
      end,
    );
    if (appId == null || appId.trim().isEmpty) {
      return events;
    }

    return List<AppOpenEvent>.unmodifiable(
      events.where((event) => event.appId == appId),
    );
  }

  Future<List<NotificationEvent>> loadNotificationEvents({
    required DateTime start,
    required DateTime end,
    String? appId,
  }) async {
    if (!_notificationAccessService.isSupported || !end.isAfter(start)) {
      return const <NotificationEvent>[];
    }

    final granted = await _notificationAccessService.hasAccess();
    if (!granted) return const <NotificationEvent>[];

    final events = await _notificationAccessService.queryEvents(
      start: start,
      end: end,
    );
    if (appId == null || appId.trim().isEmpty) {
      return events;
    }

    return List<NotificationEvent>.unmodifiable(
      events.where((event) => event.packageName == appId),
    );
  }

  List<Duration> hourlyUsageForAppToday(String appId) {
    final summary = _todaySummary;
    if (summary == null) {
      return List<Duration>.filled(24, Duration.zero, growable: false);
    }

    final appRecords = _todayRecords
        .where((record) => record.appId == appId)
        .toList(growable: false);
    final appSummary = _usageAnalyzer.buildDailySummary(
      summary.date,
      appRecords,
    );

    final values = List<Duration>.filled(24, Duration.zero, growable: false);
    for (final hour in appSummary.hourlyUsage) {
      final index = hour.hourStart.hour;
      if (index >= 0 && index < values.length) {
        values[index] = hour.totalUsage;
      }
    }
    return values;
  }

  Duration focusDistractionDurationForApp(
    String appId, {
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) return Duration.zero;
    final ranges = <_UsageTimeRange>[];

    for (final analysis in _focusAnalysesBySessionId.values) {
      for (final interruption in analysis.interruptions) {
        if (interruption.appId != appId ||
            !interruption.endTime.isAfter(start) ||
            !interruption.startTime.isBefore(end)) {
          continue;
        }
        final clippedStart = interruption.startTime.isBefore(start)
            ? start
            : interruption.startTime;
        final clippedEnd = interruption.endTime.isAfter(end)
            ? end
            : interruption.endTime;
        if (clippedEnd.isAfter(clippedStart)) {
          ranges.add(_UsageTimeRange(clippedStart, clippedEnd));
        }
      }
    }

    return _sumMergedRanges(ranges);
  }

  int focusInterruptionCountForApp(
    String appId, {
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) return 0;
    final ranges = <_UsageTimeRange>[];
    for (final analysis in _focusAnalysesBySessionId.values) {
      for (final interruption in analysis.interruptions) {
        if (interruption.appId != appId ||
            !interruption.endTime.isAfter(start) ||
            !interruption.startTime.isBefore(end)) {
          continue;
        }
        final clippedStart = interruption.startTime.isBefore(start)
            ? start
            : interruption.startTime;
        final clippedEnd = interruption.endTime.isAfter(end)
            ? end
            : interruption.endTime;
        if (clippedEnd.isAfter(clippedStart)) {
          ranges.add(_UsageTimeRange(clippedStart, clippedEnd));
        }
      }
    }
    return _mergeUsageRanges(ranges).length;
  }

  Future<List<DailyUsageMetrics>> loadDailyUsageHistory({
    int days = 7,
    DateTime? endDay,
    bool backfillRecentMissingDays = true,
    bool includeMissingDays = true,
  }) async {
    if (days <= 0) {
      return const <DailyUsageMetrics>[];
    }

    final now = DateTime.now();
    final normalizedEnd = _startOfDay(endDay ?? now);
    final start = DateTime(
      normalizedEnd.year,
      normalizedEnd.month,
      normalizedEnd.day - (days - 1),
    );

    final values = <DailyUsageMetrics>[];

    for (var index = 0; index < days; index++) {
      final day = DateTime(start.year, start.month, start.day + index);
      if (_isBeforeHistoryStart(day)) {
        if (includeMissingDays) {
          values.add(_missingDailyUsage(day));
        }
        continue;
      }

      final resolved = await _resolveUsageDay(
        day,
        now: now,
        backfillRecentMissingDays: backfillRecentMissingDays,
      );

      if (resolved == null) {
        if (includeMissingDays) {
          values.add(_missingDailyUsage(day));
        }
        continue;
      }

      values.add(
        _buildDailyUsageMetrics(
          day,
          resolved.snapshot.records,
          resolved.provenance,
          completeDay: resolved.completeDay,
        ),
      );
    }

    return List<DailyUsageMetrics>.unmodifiable(values);
  }

  UsageDataCoverage coverageForAppHistory(List<AppUsageHistoryPoint> points) {
    return UsageDataCoverage.fromMeasurements(
      points.map(
        (point) => UsageCoverageSample(
          provenance: point.provenance,
          completeDay: point.completeDay,
        ),
      ),
    );
  }

  UsageDataCoverage coverageForDailyUsage(List<DailyUsageMetrics> days) {
    return UsageDataCoverage.fromMeasurements(
      days.map(
        (day) => UsageCoverageSample(
          provenance: day.provenance,
          completeDay: day.completeDay,
        ),
      ),
    );
  }

  bool canCompareUsagePeriods(
    List<DailyUsageMetrics> current,
    List<DailyUsageMetrics> previous,
  ) {
    final currentCoverage = coverageForDailyUsage(current);
    final previousCoverage = coverageForDailyUsage(previous);
    return currentCoverage.isSufficientForPeriodComparison &&
        previousCoverage.isSufficientForPeriodComparison;
  }

  double? compareDurationsPercent(
    Duration current,
    Duration previous, {
    required bool comparisonAllowed,
  }) {
    if (!comparisonAllowed) {
      return null;
    }

    if (previous.inSeconds == 0) {
      return current.inSeconds == 0 ? 0 : null;
    }

    return ((current.inSeconds - previous.inSeconds) / previous.inSeconds) *
        100;
  }

  FocusAnalysisResult? analysisForSession(String sessionId) {
    return _focusAnalysesBySessionId[sessionId];
  }

  FocusAnalysisCoverage focusAnalysisCoverageForSessions(
    Iterable<FocusSession> sessions,
  ) {
    final ids = <String>{};
    for (final session in sessions) {
      ids.add(session.id);
    }

    var analyzed = 0;
    for (final id in ids) {
      if (_focusAnalysesBySessionId.containsKey(id)) {
        analyzed++;
      }
    }

    return FocusAnalysisCoverage(
      totalSessions: ids.length,
      analyzedSessions: analyzed,
    );
  }

  Duration focusDistractedDurationForDate(DateTime date) {
    final dayStart = _startOfDay(date);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    final ranges = <_UsageTimeRange>[];

    for (final analysis in _focusAnalysesBySessionId.values) {
      for (final interruption in analysis.interruptions) {
        if (!interruption.endTime.isAfter(dayStart) ||
            !interruption.startTime.isBefore(dayEnd)) {
          continue;
        }

        final start = interruption.startTime.isBefore(dayStart)
            ? dayStart
            : interruption.startTime;
        final end = interruption.endTime.isAfter(dayEnd)
            ? dayEnd
            : interruption.endTime;

        if (end.isAfter(start)) {
          ranges.add(_UsageTimeRange(start, end));
        }
      }
    }

    return _sumMergedRanges(ranges);
  }

  int focusInterruptionCountForDate(DateTime date) {
    final dayStart = _startOfDay(date);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    final ranges = <_UsageTimeRange>[];

    for (final analysis in _focusAnalysesBySessionId.values) {
      for (final interruption in analysis.interruptions) {
        if (!interruption.endTime.isAfter(dayStart) ||
            !interruption.startTime.isBefore(dayEnd)) {
          continue;
        }

        final start = interruption.startTime.isBefore(dayStart)
            ? dayStart
            : interruption.startTime;
        final end = interruption.endTime.isAfter(dayEnd)
            ? dayEnd
            : interruption.endTime;
        if (end.isAfter(start)) {
          ranges.add(_UsageTimeRange(start, end));
        }
      }
    }

    return _mergeUsageRanges(ranges).length;
  }

  String? topInterrupterForRange(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      return null;
    }

    final byApp = <String, List<_UsageTimeRange>>{};

    for (final analysis in _focusAnalysesBySessionId.values) {
      for (final interruption in analysis.interruptions) {
        if (!interruption.endTime.isAfter(start) ||
            !interruption.startTime.isBefore(end)) {
          continue;
        }

        final clippedStart = interruption.startTime.isBefore(start)
            ? start
            : interruption.startTime;
        final clippedEnd = interruption.endTime.isAfter(end)
            ? end
            : interruption.endTime;
        if (!clippedEnd.isAfter(clippedStart)) {
          continue;
        }

        byApp
            .putIfAbsent(interruption.appName, () => <_UsageTimeRange>[])
            .add(_UsageTimeRange(clippedStart, clippedEnd));
      }
    }

    String? winner;
    var winnerDuration = Duration.zero;

    for (final entry in byApp.entries) {
      final duration = _sumMergedRanges(entry.value);
      if (duration.compareTo(winnerDuration) > 0) {
        winnerDuration = duration;
        winner = entry.key;
      }
    }

    return winner;
  }

  Future<_ResolvedUsageDay?> _resolveUsageDay(
    DateTime day, {
    required DateTime now,
    required bool backfillRecentMissingDays,
  }) async {
    final normalizedDay = _startOfDay(day);
    if (_isBeforeHistoryStart(normalizedDay)) {
      return null;
    }

    final normalizedToday = _startOfDay(now);
    final yesterday = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day - 1,
    );

    if (_sameDate(normalizedDay, normalizedToday) &&
        _todaySummary != null &&
        _todayRecords.isNotEmpty) {
      return _ResolvedUsageDay(
        snapshot: UsageDaySnapshot(
          day: normalizedDay,
          updatedAt: _lastUpdatedAt ?? now,
          records: List<AppUsageRecord>.unmodifiable(_todayRecords),
        ),
        provenance: _todayProvenance.measured
            ? _todayProvenance
            : UsageDataProvenance.liveAndroid,
        completeDay: false,
      );
    }

    if (_sameDate(normalizedDay, yesterday) && _yesterdaySummary != null) {
      return _ResolvedUsageDay(
        snapshot: UsageDaySnapshot(
          day: normalizedDay,
          updatedAt: _lastUpdatedAt ?? now,
          records: List<AppUsageRecord>.unmodifiable(_yesterdayRecords),
        ),
        provenance: _yesterdayProvenance.measured
            ? _yesterdayProvenance
            : UsageDataProvenance.androidHistory,
        completeDay: true,
      );
    }

    final store = _storageService;
    if (store != null) {
      final stored = await store.loadDay(normalizedDay);
      if (stored != null) {
        final boundedRecords = _applyHistoryBoundary(
          normalizedDay,
          stored.records,
        );
        if (boundedRecords.isEmpty) {
          await store.deleteDay(normalizedDay);
        } else {
          if (boundedRecords.length != stored.records.length) {
            await store.saveDay(
              normalizedDay,
              boundedRecords,
              updatedAt: stored.updatedAt,
            );
          }
          return _ResolvedUsageDay(
            snapshot: UsageDaySnapshot(
              day: stored.day,
              updatedAt: stored.updatedAt,
              records: List<AppUsageRecord>.unmodifiable(boundedRecords),
            ),
            provenance: UsageDataProvenance.focusedStorage,
            completeDay: normalizedDay.isBefore(normalizedToday),
          );
        }
      }
    }

    if (!backfillRecentMissingDays || !_usageStatsService.isSupported) {
      return null;
    }

    final recentBackfillStart = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day - 6,
    );

    if (normalizedDay.isBefore(recentBackfillStart) ||
        normalizedDay.isAfter(normalizedToday)) {
      return null;
    }

    var granted = false;
    try {
      granted = await _usageStatsService.hasUsageAccess();
    } catch (_) {
      return null;
    }

    if (!granted) {
      return null;
    }

    _accessStatus = UsageAccessStatus.granted;
    final queryEnd = _sameDate(normalizedDay, normalizedToday)
        ? now
        : DateTime(
            normalizedDay.year,
            normalizedDay.month,
            normalizedDay.day + 1,
          );

    try {
      final records = await _usageStatsService.queryUsageRecords(
        _effectiveQueryStart(normalizedDay),
        queryEnd,
      );
      if (records.isEmpty) {
        if (store != null) {
          await store.deleteDay(normalizedDay);
        }
        return null;
      }

      final snapshot = UsageDaySnapshot(
        day: normalizedDay,
        updatedAt: now,
        records: List<AppUsageRecord>.unmodifiable(records),
      );

      if (store != null) {
        await store.saveDay(normalizedDay, records, updatedAt: now);
      }

      if (_sameDate(normalizedDay, normalizedToday)) {
        _todayRecords = List.of(records);
        _todaySummary = _usageAnalyzer.buildDailySummary(
          normalizedDay,
          _todayRecords,
        );
        _todayProvenance = UsageDataProvenance.liveAndroid;
        _lastUpdatedAt = now;
      } else if (_sameDate(normalizedDay, yesterday)) {
        _yesterdayRecords = List.of(records);
        _yesterdaySummary = _usageAnalyzer.buildDailySummary(
          normalizedDay,
          _yesterdayRecords,
        );
        _yesterdayProvenance = UsageDataProvenance.androidHistory;
      }

      return _ResolvedUsageDay(
        snapshot: snapshot,
        provenance: _sameDate(normalizedDay, normalizedToday)
            ? UsageDataProvenance.liveAndroid
            : UsageDataProvenance.androidHistory,
        completeDay: !_sameDate(normalizedDay, normalizedToday),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _effectiveQueryStart(DateTime day) {
    final normalized = _startOfDay(day);
    final historyStart = _historyStartedAt;
    if (historyStart == null) return normalized;

    final localStart = historyStart.toLocal();
    if (_sameDate(normalized, localStart) && localStart.isAfter(normalized)) {
      return localStart;
    }
    return normalized;
  }

  List<AppUsageRecord> _applyHistoryBoundary(
    DateTime day,
    List<AppUsageRecord> records,
  ) {
    final queryStart = _effectiveQueryStart(day);
    if (queryStart == _startOfDay(day)) {
      return List<AppUsageRecord>.unmodifiable(records);
    }

    final bounded = <AppUsageRecord>[];
    for (final record in records) {
      if (!record.endTime.isAfter(queryStart)) {
        continue;
      }
      bounded.add(
        record.startTime.isBefore(queryStart)
            ? record.copyWith(startTime: queryStart)
            : record,
      );
    }
    return List<AppUsageRecord>.unmodifiable(bounded);
  }

  bool _isBeforeHistoryStart(DateTime day) {
    final start = usageHistoryStartDay;
    if (start == null) return false;
    return _startOfDay(day).isBefore(start);
  }

  DailyUsageMetrics _missingDailyUsage(DateTime day) {
    return DailyUsageMetrics(
      day: _startOfDay(day),
      provenance: UsageDataProvenance.missing,
      completeDay: false,
      totalUsage: Duration.zero,
      productiveUsage: Duration.zero,
      neutralUsage: Duration.zero,
      distractingUsage: Duration.zero,
      topApps: const <AppUsageAppEntry>[],
    );
  }

  DailyUsageMetrics _buildDailyUsageMetrics(
    DateTime day,
    List<AppUsageRecord> records,
    UsageDataProvenance provenance, {
    required bool completeDay,
  }) {
    final totalSummary = _usageAnalyzer.buildDailySummary(day, records);

    Duration categoryDuration(AppCategory category) {
      final filtered = records.where((record) {
        return _resolvedCategoryForRecord(record) == category;
      }).toList();
      if (filtered.isEmpty) {
        return Duration.zero;
      }
      return _usageAnalyzer.buildDailySummary(day, filtered).totalUsage;
    }

    final byId = <String, List<AppUsageRecord>>{};
    final names = <String, String>{};
    for (final record in records) {
      byId.putIfAbsent(record.appId, () => <AppUsageRecord>[]).add(record);
      names[record.appId] = record.appName;
    }

    final topApps = <AppUsageAppEntry>[];
    for (final entry in byId.entries) {
      final summary = _usageAnalyzer.buildDailySummary(day, entry.value);
      final metadata = _appMetadataById[entry.key];
      topApps.add(
        AppUsageAppEntry(
          appId: entry.key,
          appName: resolveDisplayName(
            entry.key,
            fallback: names[entry.key] ?? entry.key,
          ),
          duration: summary.totalUsage,
          iconBytes: metadata?.iconBytes,
        ),
      );
    }
    topApps.sort((a, b) => b.duration.compareTo(a.duration));

    return DailyUsageMetrics(
      day: _startOfDay(day),
      provenance: provenance,
      completeDay: completeDay,
      totalUsage: totalSummary.totalUsage,
      productiveUsage: categoryDuration(AppCategory.productive),
      neutralUsage: categoryDuration(AppCategory.neutral),
      distractingUsage: categoryDuration(AppCategory.distracting),
      topApps: List<AppUsageAppEntry>.unmodifiable(topApps.take(5)),
    );
  }

  AppCategory _resolvedCategoryForRecord(AppUsageRecord record) {
    return _userAppCategories[record.appId] ??
        _userAppCategories[record.appName] ??
        _defaultAppCategories[record.appId] ??
        _defaultAppCategories[record.appName] ??
        AppCategory.neutral;
  }

  double? usageComparisonPercent(
    AppUsageHistoryPoint current,
    AppUsageHistoryPoint previous,
  ) {
    if (!current.measured || !previous.measured) {
      return null;
    }

    if (current.completeDay != previous.completeDay) {
      return null;
    }

    if (previous.usage.inSeconds == 0) {
      return current.usage.inSeconds == 0 ? 0 : null;
    }

    return ((current.usage.inSeconds - previous.usage.inSeconds) /
            previous.usage.inSeconds) *
        100;
  }

  /// Compares the average of the newer half of measured days with the older
  /// half. An odd middle point is ignored so both halves have equal weight.
  double? usageTrendPercent(List<AppUsageHistoryPoint> points) {
    final coverage = coverageForAppHistory(points);
    if (!coverage.isSufficientForTrend) {
      return null;
    }

    final measured = points
        .where((point) => point.measured && point.completeDay)
        .toList();

    final half = measured.length ~/ 2;
    final older = measured.take(half).toList();
    final newer = measured.skip(measured.length - half).toList();

    double average(List<AppUsageHistoryPoint> values) {
      final total = values.fold<int>(
        0,
        (sum, point) => sum + point.usage.inSeconds,
      );
      return total / values.length;
    }

    final olderAverage = average(older);
    final newerAverage = average(newer);

    if (olderAverage == 0) {
      return newerAverage == 0 ? 0 : null;
    }

    return ((newerAverage - olderAverage) / olderAverage) * 100;
  }

  DailyUsageSummary? _comparableYesterdaySummary() {
    final yesterdaySummary = _yesterdaySummary;
    final records = _comparableYesterdayRecords();
    if (yesterdaySummary == null || records == null) {
      return null;
    }
    return _usageAnalyzer.buildDailySummary(yesterdaySummary.date, records);
  }

  List<AppUsageRecord>? _comparableYesterdayRecords() {
    if (_todaySummary == null || _yesterdaySummary == null) {
      return null;
    }

    final reference = _lastUpdatedAt ?? DateTime.now();
    final todayStart = _startOfDay(reference);
    var elapsed = reference.difference(todayStart);
    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }
    if (elapsed > const Duration(days: 1)) {
      elapsed = const Duration(days: 1);
    }

    final yesterdayStart = _yesterdaySummary!.date;
    final cutoff = yesterdayStart.add(elapsed);
    final clipped = <AppUsageRecord>[];

    for (final record in _yesterdayRecords) {
      if (!record.endTime.isAfter(yesterdayStart) ||
          !record.startTime.isBefore(cutoff)) {
        continue;
      }

      final start = record.startTime.isBefore(yesterdayStart)
          ? yesterdayStart
          : record.startTime;
      final end = record.endTime.isAfter(cutoff) ? cutoff : record.endTime;

      if (!end.isAfter(start)) {
        continue;
      }

      clipped.add(
        AppUsageRecord(
          appId: record.appId,
          appName: record.appName,
          startTime: start,
          endTime: end,
        ),
      );
    }

    return List<AppUsageRecord>.unmodifiable(clipped);
  }

  Duration _usageForAppInRecords(
    String appId,
    DateTime day,
    List<AppUsageRecord> records,
  ) {
    final filtered = records.where((record) => record.appId == appId).toList();

    if (filtered.isEmpty) {
      return Duration.zero;
    }

    return _usageAnalyzer.buildDailySummary(day, filtered).totalUsage;
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

class _ResolvedUsageDay {
  final UsageDaySnapshot snapshot;
  final UsageDataProvenance provenance;
  final bool completeDay;

  const _ResolvedUsageDay({
    required this.snapshot,
    required this.provenance,
    required this.completeDay,
  });
}

class _UsageTimeRange {
  final DateTime start;
  final DateTime end;

  const _UsageTimeRange(this.start, this.end);
}

List<_UsageTimeRange> _mergeUsageRanges(List<_UsageTimeRange> ranges) {
  final values =
      ranges.where((range) => range.end.isAfter(range.start)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  if (values.isEmpty) {
    return const <_UsageTimeRange>[];
  }

  final merged = <_UsageTimeRange>[];
  var current = values.first;

  for (var index = 1; index < values.length; index++) {
    final next = values[index];
    if (!next.start.isAfter(current.end)) {
      current = _UsageTimeRange(
        current.start,
        next.end.isAfter(current.end) ? next.end : current.end,
      );
      continue;
    }
    merged.add(current);
    current = next;
  }

  merged.add(current);
  return merged;
}

Duration _sumMergedRanges(List<_UsageTimeRange> ranges) {
  var total = Duration.zero;
  for (final range in _mergeUsageRanges(ranges)) {
    total += range.end.difference(range.start);
  }
  return total;
}

bool _looksLikeAndroidPackage(String value) {
  final trimmed = value.trim();
  return trimmed.contains('.') &&
      !trimmed.contains(' ') &&
      !trimmed.contains('/');
}

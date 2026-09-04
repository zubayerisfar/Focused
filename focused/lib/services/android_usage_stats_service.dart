import 'dart:io';

import 'package:usage_stats/usage_stats.dart';

import '../models/app_open_event.dart';
import '../models/app_usage_record.dart';
import 'app_metadata_platform_service.dart';
import 'app_open_counter.dart';
import 'usage_event_normalizer.dart';
import 'usage_stats_service.dart';

class AndroidUsageStatsService implements UsageStatsService {
  AndroidUsageStatsService({
    UsageEventNormalizer normalizer = const UsageEventNormalizer(),
    AppOpenCounter appOpenCounter = const AppOpenCounter(),
    AppMetadataPlatformService? appMetadataService,
  }) : _normalizer = normalizer,
       _appOpenCounter = appOpenCounter,
       _appMetadataService = appMetadataService ?? AndroidAppMetadataService();

  final UsageEventNormalizer _normalizer;
  final AppOpenCounter _appOpenCounter;
  final AppMetadataPlatformService _appMetadataService;

  final Map<String, String> _appNameCache = {};
  String? _cachedDefaultLauncher;

  static const Duration _boundaryLookback = Duration(days: 1);

  static const Set<String> _ignoredPackages = {
    // Core Android Framework & System UI
    'android',
    'com.android.systemui',
    'com.android.keyguard',
    'com.android.settings',
    'com.google.android.permissioncontroller',
    'com.android.permissioncontroller',
    'com.google.android.packageinstaller',
    'com.android.packageinstaller',
    'com.android.intentresolver',
    'com.android.documentsui',
    'com.google.android.setupwizard',
    'com.android.setupwizard',
    'com.google.android.gms',
    // OEM Launchers & Home Screens (Moto, Pixel, Samsung, Xiaomi, OnePlus, Nova, etc.)
    'com.motorola.launcher3',
    'com.motorola.launcher',
    'com.motorola.gesture',
    'com.google.android.apps.nexuslauncher',
    'com.sec.android.app.launcher',
    'com.miui.home',
    'com.mi.android.globallauncher',
    'com.oppo.launcher',
    'com.oneplus.launcher',
    'com.teslacoilsw.launcher',
    'com.microsoft.launcher',
    'com.android.launcher',
    'com.android.launcher2',
    'com.android.launcher3',
    // Keyboards & Input Methods
    'com.google.android.inputmethod.latin',
    'com.touchtype.swiftkey',
    'com.samsung.android.honeyboard',
  };

  Future<Set<String>> _getEffectiveIgnoredPackages() async {
    if (_cachedDefaultLauncher == null) {
      try {
        _cachedDefaultLauncher = await _appMetadataService
            .getDefaultLauncherPackage();
      } catch (_) {}
    }
    if (_cachedDefaultLauncher != null && _cachedDefaultLauncher!.isNotEmpty) {
      return {..._ignoredPackages, _cachedDefaultLauncher!};
    }
    return _ignoredPackages;
  }

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<bool> hasUsageAccess() async {
    if (!isSupported) {
      return false;
    }

    return await UsageStats.checkUsagePermission() ?? false;
  }

  @override
  Future<void> requestUsageAccess() async {
    if (!isSupported) {
      return;
    }

    await UsageStats.grantUsagePermission();
  }

  @override
  Future<void> openUsageAccessSettings() async {
    if (!isSupported) {
      return;
    }

    await UsageStats.openUsageAccessSettings();
  }

  @override
  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSupported) {
      return const [];
    }

    if (!end.isAfter(start)) {
      return const [];
    }

    final granted = await hasUsageAccess();
    if (!granted) {
      throw StateError('Android Usage Access has not been granted.');
    }

    final effectiveIgnored = await _getEffectiveIgnoredPackages();

    // Look behind the requested boundary so an app that entered the
    // foreground just before midnight/range start can still be reconstructed.
    final queryStart = start.subtract(_boundaryLookback);
    final rawEvents = await UsageStats.queryEvents(queryStart, end);

    final points = <UsageEventPoint>[];

    for (final event in rawEvents) {
      final timestamp = event.timeStampDate;
      final kind = _mapEventType(event.eventTypeValue);

      if (timestamp == null || kind == null) {
        continue;
      }

      final packageName = event.packageName;
      final isAppLifecycleEvent =
          kind == UsageEventKind.foreground ||
          kind == UsageEventKind.background;

      if (isAppLifecycleEvent &&
          packageName != null &&
          effectiveIgnored.contains(packageName)) {
        continue;
      }

      points.add(
        UsageEventPoint(
          packageName: packageName,
          className: event.className,
          timestamp: timestamp,
          kind: kind,
        ),
      );
    }

    final normalized = _normalizer.normalize(
      rangeStart: start,
      rangeEnd: end,
      events: points,
    );

    if (normalized.isEmpty) {
      return const [];
    }

    final packages = normalized.map((record) => record.appId).toSet();
    final labels = <String, String>{};

    await Future.wait(
      packages.map((packageName) async {
        labels[packageName] = await _resolveAppName(packageName);
      }),
    );

    return List.unmodifiable(
      normalized.map(
        (record) =>
            record.copyWith(appName: labels[record.appId] ?? record.appId),
      ),
    );
  }

  @override
  Future<List<AppOpenEvent>> queryAppOpenEvents(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSupported) {
      return const [];
    }

    if (!end.isAfter(start)) {
      return const [];
    }

    final granted = await hasUsageAccess();
    if (!granted) {
      throw StateError('Android Usage Access has not been granted.');
    }

    final effectiveIgnored = await _getEffectiveIgnoredPackages();

    final queryStart = start.subtract(_boundaryLookback);
    final rawEvents = await UsageStats.queryEvents(queryStart, end);
    final points = <UsageEventPoint>[];
    for (final event in rawEvents) {
      final timestamp = event.timeStampDate;
      final kind = _mapEventType(event.eventTypeValue);
      if (timestamp == null || kind == null) continue;
      points.add(
        UsageEventPoint(
          packageName: event.packageName,
          className: event.className,
          timestamp: timestamp,
          kind: kind,
        ),
      );
    }

    final rawOpenings = _appOpenCounter.count(
      rangeStart: start,
      rangeEnd: end,
      events: points,
      ignoredPackages: effectiveIgnored,
    );
    if (rawOpenings.isEmpty) return const [];

    final labels = <String, String>{};
    await Future.wait(
      rawOpenings.map((item) => item.appId).toSet().map((packageName) async {
        labels[packageName] = await _resolveAppName(packageName);
      }),
    );

    return List<AppOpenEvent>.unmodifiable(
      rawOpenings.map(
        (item) => AppOpenEvent(
          appId: item.appId,
          appName: labels[item.appId] ?? item.appId,
          timestamp: item.timestamp,
        ),
      ),
    );
  }

  UsageEventKind? _mapEventType(int? value) {
    switch (value) {
      // MOVE_TO_FOREGROUND and ACTIVITY_RESUMED share value 1.
      case 1:
        return UsageEventKind.foreground;

      // MOVE_TO_BACKGROUND and ACTIVITY_PAUSED share value 2.
      case 2:
      case 23: // ACTIVITY_STOPPED
        return UsageEventKind.background;

      case 15: // SCREEN_INTERACTIVE
        return UsageEventKind.screenInteractive;

      case 16: // SCREEN_NON_INTERACTIVE
      case 17: // KEYGUARD_SHOWN
        return UsageEventKind.screenNonInteractive;

      case 26: // DEVICE_SHUTDOWN
        return UsageEventKind.deviceShutdown;

      case 27: // DEVICE_STARTUP
        return UsageEventKind.deviceStartup;

      default:
        return null;
    }
  }

  Future<String> _resolveAppName(String packageName) async {
    final cached = _appNameCache[packageName];
    if (cached != null) {
      return cached;
    }

    try {
      final info = await UsageStats.getAppInfo(packageName);
      final label = info?.appName?.trim();

      if (label != null && label.isNotEmpty) {
        _appNameCache[packageName] = label;
        return label;
      }
    } catch (_) {
      // Package visibility rules can prevent metadata resolution on Android 11+
      // even though UsageStats still reports the package id. The package id is
      // an honest fallback and is preferable to inventing a label.
    }

    _appNameCache[packageName] = packageName;
    return packageName;
  }
}

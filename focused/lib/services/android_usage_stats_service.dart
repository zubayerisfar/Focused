import 'dart:io';

import 'package:usage_stats/usage_stats.dart';

import '../models/app_usage_record.dart';
import 'usage_event_normalizer.dart';
import 'usage_stats_service.dart';

class AndroidUsageStatsService implements UsageStatsService {
  AndroidUsageStatsService({
    UsageEventNormalizer normalizer = const UsageEventNormalizer(),
  }) : _normalizer = normalizer;

  final UsageEventNormalizer _normalizer;

  final Map<String, String> _appNameCache = {};

  static const Duration _boundaryLookback = Duration(days: 1);

  static const Set<String> _ignoredPackages = {
    'android',
    'com.android.systemui',
  };

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
          kind == UsageEventKind.foreground || kind == UsageEventKind.background;

      if (isAppLifecycleEvent &&
          packageName != null &&
          _ignoredPackages.contains(packageName)) {
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
        (record) => record.copyWith(
          appName: labels[record.appId] ?? record.appId,
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

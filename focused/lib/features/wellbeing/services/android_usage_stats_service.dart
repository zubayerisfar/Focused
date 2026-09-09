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
    'com.bbk.launcher2',
    'com.vivo.upslide',
    'com.vivo.doubleinstance',
    'com.teslacoilsw.launcher',
    'com.microsoft.launcher',
    'com.android.launcher',
    'com.android.launcher2',
    'com.android.launcher3',
    // Keyboards & Input Methods
    'com.google.android.inputmethod.latin',
    'com.touchtype.swiftkey',
    'com.samsung.android.honeyboard',
    // System Clocks, Alarms & Timers (prevent phantom background lockscreen/alarm time)
    'com.google.android.deskclock',
    'com.android.deskclock',
    'com.sec.android.app.clockpackage',
    'com.motorola.timeweatherwidget',
    'com.oneplus.deskclock',
    'com.coloros.alarm',
    'com.miui.clock',
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
    DateTime end, {
    bool reconcileWithDailyAggregates = true,
  }) async {
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

    // If aggregate reconciliation is disabled (e.g. for focus session windows where
    // daily aggregates would falsely synthesize whole-day usage into a short session),
    // or if the queried window is shorter than an hour (aggregates are daily buckets),
    // rely purely on the normalized event stream.
    if (!reconcileWithDailyAggregates ||
        end.difference(start) < const Duration(hours: 1)) {
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

    // Reconcile with Android's system-level aggregate usage stats.
    // Digital Wellbeing uses UsageStatsManager.queryUsageStats() which counts
    // foreground time at the kernel level and does not lose time when OEMs (like Xiaomi)
    // truncate or drop granular events.
    final aggregateMap = await queryDailyAggregateUsage(start, end);

    final finalRecords = <AppUsageRecord>[];
    final normalizedByPackage = <String, List<AppUsageRecord>>{};
    for (final r in normalized) {
      normalizedByPackage.putIfAbsent(r.appId, () => []).add(r);
    }

    // Combine packages present in normalized events and in aggregate data
    final allPackages = {...normalizedByPackage.keys, ...aggregateMap.keys};

    for (final pkg in allPackages) {
      if (effectiveIgnored.contains(pkg)) {
        continue;
      }

      final records = normalizedByPackage[pkg] ?? const <AppUsageRecord>[];
      final aggregateDuration = aggregateMap[pkg] ?? Duration.zero;

      if (records.isEmpty) {
        // App had foreground time according to the OS aggregate, but raw events
        // were pruned/evicted by the OS. Synthesize a record matching the aggregate duration.
        if (aggregateDuration > Duration.zero) {
          final effectiveDuration = aggregateDuration > end.difference(start)
              ? end.difference(start)
              : aggregateDuration;
          final recordStart = end.subtract(effectiveDuration);
          final safeStart = recordStart.isBefore(start) ? start : recordStart;
          final safeEnd = safeStart.add(effectiveDuration);
          if (safeEnd.isAfter(safeStart)) {
            finalRecords.add(
              AppUsageRecord(
                appId: pkg,
                appName: pkg,
                startTime: safeStart,
                endTime: safeEnd.isAfter(end) ? end : safeEnd,
              ),
            );
          }
        }
      } else {
        // App has raw event intervals. Check if raw events severely undercounted
        // compared to the OS aggregate.
        final rawTotalSeconds = records.fold<int>(
          0,
          (sum, r) => sum + r.duration.inSeconds,
        );
        final aggSeconds = aggregateDuration.inSeconds;

        if (aggSeconds > rawTotalSeconds && rawTotalSeconds > 0) {
          // Proportionally scale the intervals to match the OS's canonical foreground count,
          // but cap the ratio to 1.5x to prevent inflated counts on OEM ROMs where aggregate
          // includes rolling 24h buckets instead of strict midnight-to-now.
          final safeAggSeconds = aggSeconds > end.difference(start).inSeconds
              ? end.difference(start).inSeconds
              : aggSeconds;
          final ratio = (safeAggSeconds / rawTotalSeconds).clamp(1.0, 1.5);
          var lastEnd = start;
          for (final r in records) {
            final origDuration = r.duration;
            final scaledDuration = Duration(
              milliseconds: (origDuration.inMilliseconds * ratio).round(),
            );
            final newStart = r.startTime.isBefore(lastEnd)
                ? lastEnd
                : r.startTime;
            var newEnd = newStart.add(scaledDuration);
            if (newEnd.isAfter(end)) {
              newEnd = end;
            }
            if (newEnd.isAfter(newStart)) {
              finalRecords.add(
                AppUsageRecord(
                  appId: pkg,
                  appName: pkg,
                  startTime: newStart,
                  endTime: newEnd,
                ),
              );
              lastEnd = newEnd;
            }
          }
        } else if (aggSeconds > 0 && rawTotalSeconds == 0) {
          final effectiveDuration = aggregateDuration > end.difference(start)
              ? end.difference(start)
              : aggregateDuration;
          final recordStart = end.subtract(effectiveDuration);
          final safeStart = recordStart.isBefore(start) ? start : recordStart;
          final safeEnd = safeStart.add(effectiveDuration);
          if (safeEnd.isAfter(safeStart)) {
            finalRecords.add(
              AppUsageRecord(
                appId: pkg,
                appName: pkg,
                startTime: safeStart,
                endTime: safeEnd.isAfter(end) ? end : safeEnd,
              ),
            );
          }
        } else {
          finalRecords.addAll(records);
        }
      }
    }

    if (finalRecords.isEmpty) {
      return const [];
    }

    final packages = finalRecords.map((record) => record.appId).toSet();
    final labels = <String, String>{};

    await Future.wait(
      packages.map((packageName) async {
        labels[packageName] = await _resolveAppName(packageName);
      }),
    );

    return List.unmodifiable(
      finalRecords.map(
        (record) =>
            record.copyWith(appName: labels[record.appId] ?? record.appId),
      ),
    );
  }

  @override
  Future<Map<String, Duration>> queryDailyAggregateUsage(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSupported || !end.isAfter(start)) {
      return const {};
    }

    final granted = await hasUsageAccess();
    if (!granted) {
      return const {};
    }

    try {
      final effectiveIgnored = await _getEffectiveIgnoredPackages();
      final aggregate = await UsageStats.queryAndAggregateUsageStats(
        start,
        end,
      );
      final result = <String, Duration>{};

      for (final entry in aggregate.entries) {
        final pkg = entry.key.trim();
        if (pkg.isEmpty || effectiveIgnored.contains(pkg)) {
          continue;
        }

        final ms = entry.value.totalTimeInForegroundMs;
        if (ms != null && ms > 0) {
          result[pkg] = Duration(milliseconds: ms);
        }
      }

      return result;
    } catch (_) {
      return const {};
    }
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

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_category.dart';
import 'package:focused/models/app_metadata.dart';
import 'package:focused/services/app_metadata_platform_service.dart';
import 'package:focused/services/app_metadata_storage_service.dart';
import 'package:focused/models/app_usage_history_point.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/models/focus_analysis_result.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/models/usage_access_status.dart';
import 'package:focused/models/daily_usage_metrics.dart';
import 'package:focused/models/usage_data_provenance.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/services/app_category_storage_service.dart';
import 'package:focused/services/focus_analysis_storage_service.dart';
import 'package:focused/services/usage_record_storage_service.dart';
import 'package:focused/services/usage_stats_service.dart';

void main() {
  test('loads stored usage even when permission is currently denied', () async {
    final now = DateTime(2026, 8, 28, 12);
    final store = _MemoryUsageStore();
    await store.saveDay(
      DateTime(2026, 8, 28),
      [
        AppUsageRecord(
          appId: 'com.example',
          appName: 'Example',
          startTime: DateTime(2026, 8, 28, 10),
          endTime: DateTime(2026, 8, 28, 11),
        ),
      ],
      updatedAt: DateTime(2026, 8, 28, 11, 5),
    );

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
      storageService: store,
    );

    await provider.loadStoredUsage(now: now);
    await provider.refreshPermissionAndUsage(now: now);

    expect(provider.accessStatus, UsageAccessStatus.denied);
    expect(provider.todaySummary, isNotNull);
    expect(provider.todaySummary!.totalUsage, const Duration(hours: 1));
  });

  test('granted refresh queries today and yesterday and persists both', () async {
    final now = DateTime(2026, 8, 28, 12);
    final service = _FakeUsageStatsService(
      granted: true,
      resolver: (start, end) {
        if (start.day == 28) {
          return [
            AppUsageRecord(
              appId: 'today',
              appName: 'Today App',
              startTime: DateTime(2026, 8, 28, 9),
              endTime: DateTime(2026, 8, 28, 11),
            ),
          ];
        }

        return [
          AppUsageRecord(
            appId: 'yesterday',
            appName: 'Yesterday App',
            startTime: DateTime(2026, 8, 27, 9),
            endTime: DateTime(2026, 8, 27, 10),
          ),
        ];
      },
    );
    final store = _MemoryUsageStore();

    final provider = UsageProvider(
      usageStatsService: service,
      storageService: store,
    );

    await provider.refreshPermissionAndUsage(now: now, force: true);

    expect(provider.accessStatus, UsageAccessStatus.granted);
    expect(provider.todaySummary!.totalUsage, const Duration(hours: 2));
    expect(provider.yesterdaySummary!.totalUsage, const Duration(hours: 1));
    expect(provider.todayVsYesterdayPercent, 100);
    expect(await store.loadDay(DateTime(2026, 8, 28)), isNotNull);
    expect(await store.loadDay(DateTime(2026, 8, 27)), isNotNull);
    expect(service.queryCount, 2);
  });

  test('today comparison uses the same elapsed time yesterday', () async {
    final now = DateTime(2026, 8, 28, 12);
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) {
          if (start.day == 28) {
            return [
              AppUsageRecord(
                appId: 'app',
                appName: 'App',
                startTime: DateTime(2026, 8, 28, 9),
                endTime: DateTime(2026, 8, 28, 10),
              ),
            ];
          }

          return [
            AppUsageRecord(
              appId: 'app',
              appName: 'App',
              startTime: DateTime(2026, 8, 27, 9),
              endTime: DateTime(2026, 8, 27, 10),
            ),
            AppUsageRecord(
              appId: 'app',
              appName: 'App',
              startTime: DateTime(2026, 8, 27, 18),
              endTime: DateTime(2026, 8, 27, 20),
            ),
          ];
        },
      ),
    );

    await provider.refreshPermissionAndUsage(now: now, force: true);

    // At noon, yesterday's evening usage is deliberately excluded.
    expect(provider.todayVsYesterdayPercent, 0);
    expect(provider.getAppChangePercentById('app'), 0);
  });

  test('today helpers expose top apps and unique distracting usage', () async {
    final now = DateTime(2026, 8, 28, 12);
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) {
          if (start.day != 28) {
            return const [];
          }

          return [
            AppUsageRecord(
              appId: 'com.instagram.android',
              appName: 'Instagram',
              startTime: DateTime(2026, 8, 28, 9),
              endTime: DateTime(2026, 8, 28, 10),
            ),
            AppUsageRecord(
              appId: 'com.instagram.android',
              appName: 'Instagram',
              startTime: DateTime(2026, 8, 28, 9, 30),
              endTime: DateTime(2026, 8, 28, 10, 30),
            ),
            AppUsageRecord(
              appId: 'com.google.android.youtube',
              appName: 'YouTube',
              startTime: DateTime(2026, 8, 28, 11),
              endTime: DateTime(2026, 8, 28, 11, 45),
            ),
            AppUsageRecord(
              appId: 'com.android.chrome',
              appName: 'Chrome',
              startTime: DateTime(2026, 8, 28, 10, 30),
              endTime: DateTime(2026, 8, 28, 11),
            ),
          ];
        },
      ),
    );

    await provider.refreshPermissionAndUsage(now: now, force: true);

    final top = provider.topAppsToday(limit: 3);
    expect(top.map((entry) => entry.key).toList(), [
      'Instagram',
      'YouTube',
      'Chrome',
    ]);
    expect(top.first.value, const Duration(minutes: 90));
    expect(
      provider.usageForCategoryToday(AppCategory.distracting),
      const Duration(hours: 2, minutes: 15),
    );
    expect(provider.topDistractingAppToday, 'Instagram');
  });

  test('unsupported platform reports unsupported instead of fake zero usage', () async {
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        supported: false,
        granted: false,
      ),
    );

    await provider.refreshPermissionAndUsage(
      now: DateTime(2026, 8, 28, 12),
    );

    expect(provider.accessStatus, UsageAccessStatus.unsupported);
    expect(provider.todaySummary, isNull);
  });

  test('query failure preserves previously stored snapshot', () async {
    final now = DateTime(2026, 8, 28, 12);
    final store = _MemoryUsageStore();
    await store.saveDay(
      DateTime(2026, 8, 28),
      [
        AppUsageRecord(
          appId: 'stored',
          appName: 'Stored',
          startTime: DateTime(2026, 8, 28, 8),
          endTime: DateTime(2026, 8, 28, 8, 30),
        ),
      ],
    );

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        throwOnQuery: true,
      ),
      storageService: store,
    );

    await provider.loadStoredUsage(now: now);
    await provider.refreshPermissionAndUsage(now: now, force: true);

    expect(provider.todaySummary!.totalUsage, const Duration(minutes: 30));
    expect(provider.lastError, isNotNull);
  });

  test('measured zero usage is represented as a real zero summary', () async {
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (_, __) => const [],
      ),
      storageService: _MemoryUsageStore(),
    );

    await provider.refreshPermissionAndUsage(
      now: DateTime(2026, 8, 28, 12),
      force: true,
    );

    expect(provider.todaySummary, isNotNull);
    expect(provider.todaySummary!.totalUsage, Duration.zero);
  });
  test('focus analysis queries the exact session window with real package ids', () async {
    final start = DateTime(2026, 8, 28, 10);
    final end = DateTime(2026, 8, 28, 11);
    DateTime? queriedStart;
    DateTime? queriedEnd;

    final service = _FakeUsageStatsService(
      granted: true,
      resolver: (queryStart, queryEnd) {
        queriedStart = queryStart;
        queriedEnd = queryEnd;
        return [
          AppUsageRecord(
            appId: 'com.instagram.android',
            appName: 'Instagram',
            startTime: DateTime(2026, 8, 28, 10, 10),
            endTime: DateTime(2026, 8, 28, 10, 20),
          ),
        ];
      },
    );

    final provider = UsageProvider(usageStatsService: service);

    final session = FocusSession(
      id: 'session',
      taskName: 'Study',
      startedAt: start,
      endedAt: end,
      plannedFocusDuration: const Duration(hours: 1),
      plan: const [
        FocusBlock(type: FocusBlockType.focus, duration: Duration(hours: 1)),
      ],
      focusIntervals: [
        FocusInterval(startTime: start, endTime: end),
      ],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );

    await provider.analyzeCompletedFocusSession(session);

    expect(queriedStart, start);
    expect(queriedEnd, end);
    expect(provider.focusAnalysisResult, isNotNull);
    expect(
      provider.focusAnalysisResult!.distractedDuration,
      const Duration(minutes: 10),
    );
  });

  test('focus analysis is unavailable rather than falsely perfect without permission', () async {
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
    );
    final start = DateTime(2026, 8, 28, 10);
    final end = DateTime(2026, 8, 28, 10, 30);

    final session = FocusSession(
      id: 'session',
      taskName: 'Study',
      startedAt: start,
      endedAt: end,
      plannedFocusDuration: const Duration(minutes: 30),
      plan: const [
        FocusBlock(type: FocusBlockType.focus, duration: Duration(minutes: 30)),
      ],
      focusIntervals: [FocusInterval(startTime: start, endTime: end)],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );

    await provider.analyzeCompletedFocusSession(session);

    expect(provider.focusAnalysisResult, isNull);
    expect(provider.analysisUnavailableReason, isNotNull);
    expect(provider.accessStatus, UsageAccessStatus.denied);
  });


  test('user app classification persists and overrides built-in defaults',
      () async {
    final now = DateTime(2026, 8, 29, 12);
    final categories = _MemoryCategoryStore();
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) {
          if (start.day != 29) {
            return const [];
          }

          return [
            AppUsageRecord(
              appId: 'com.instagram.android',
              appName: 'Instagram',
              startTime: DateTime(2026, 8, 29, 9),
              endTime: DateTime(2026, 8, 29, 10),
            ),
          ];
        },
      ),
      categoryStorageService: categories,
    );

    await provider.refreshPermissionAndUsage(now: now, force: true);
    expect(
      provider.usageForCategoryToday(AppCategory.distracting),
      const Duration(hours: 1),
    );

    await provider.setAppCategory(
      'com.instagram.android',
      AppCategory.neutral,
    );

    expect(
      provider.getAppCategory('com.instagram.android'),
      AppCategory.neutral,
    );
    expect(
      provider.usageForCategoryToday(AppCategory.distracting),
      Duration.zero,
    );

    final reloaded = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
      categoryStorageService: categories,
    );
    await reloaded.loadStoredCategories();

    expect(
      reloaded.getAppCategory('com.instagram.android'),
      AppCategory.neutral,
    );
  });

  test('app history keeps measured zero separate from missing days', () async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final store = _MemoryUsageStore();

    final twoDaysAgo = DateTime(day.year, day.month, day.day - 2);
    final yesterday = DateTime(day.year, day.month, day.day - 1);

    await store.saveDay(
      twoDaysAgo,
      [
        AppUsageRecord(
          appId: 'app.example',
          appName: 'Example',
          startTime: DateTime(
            twoDaysAgo.year,
            twoDaysAgo.month,
            twoDaysAgo.day,
            10,
          ),
          endTime: DateTime(
            twoDaysAgo.year,
            twoDaysAgo.month,
            twoDaysAgo.day,
            11,
          ),
        ),
      ],
    );

    // A saved empty snapshot means the day was measured and usage was zero.
    await store.saveDay(yesterday, const []);

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
      storageService: store,
    );

    final points = await provider.loadAppUsageHistory(
      'app.example',
      days: 4,
      endDay: day,
      backfillRecentMissingDays: false,
    );

    expect(points.length, 4);
    expect(points[1].day, twoDaysAgo);
    expect(points[1].measured, isTrue);
    expect(points[1].usage, const Duration(hours: 1));
    expect(points[2].day, yesterday);
    expect(points[2].measured, isTrue);
    expect(points[2].usage, Duration.zero);
    expect(points[3].day, day);
    expect(points[3].measured, isFalse);
    expect(points[3].usage, Duration.zero);
  });

  test('history trend compares equally weighted older and newer halves',
      () async {
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
    );

    final day = DateTime(2026, 8, 29);
    final points = [
      for (var index = 0; index < 6; index++)
        AppUsageHistoryPoint(
          day: DateTime(day.year, day.month, day.day - (5 - index)),
          usage: Duration(
            minutes: index < 3 ? 60 : 30,
          ),
          measured: true,
        ),
    ];

    expect(provider.usageTrendPercent(points), -50);
  });


  test('history exposes measured provenance and withholds sparse trends', () async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final store = _MemoryUsageStore();

    for (var offset = 1; offset <= 3; offset++) {
      final value = DateTime(day.year, day.month, day.day - offset);
      await store.saveDay(
        value,
        [
          AppUsageRecord(
            appId: 'app.example',
            appName: 'Example',
            startTime: DateTime(value.year, value.month, value.day, 10),
            endTime: DateTime(value.year, value.month, value.day, 11),
          ),
        ],
      );
    }

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
      storageService: store,
    );

    final points = await provider.loadAppUsageHistory(
      'app.example',
      days: 7,
      endDay: day,
      backfillRecentMissingDays: false,
    );

    final coverage = provider.coverageForAppHistory(points);
    expect(coverage.measuredDays, 3);
    expect(coverage.missingDays, 4);
    expect(coverage.isSufficientForTrend, isFalse);
    expect(provider.usageTrendPercent(points), isNull);
    expect(
      points.where((point) => point.measured).every(
            (point) =>
                point.provenance == UsageDataProvenance.focusedStorage,
          ),
      isTrue,
    );
  });

  test('recent Android backfill records provenance instead of fake stored zero',
      () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) => [
          AppUsageRecord(
            appId: 'app.example',
            appName: 'Example',
            startTime: start.add(const Duration(hours: 1)),
            endTime: start.add(const Duration(hours: 2)),
          ),
        ],
      ),
      storageService: _MemoryUsageStore(),
    );

    final values = await provider.loadDailyUsageHistory(
      days: 2,
      endDay: today,
    );

    expect(values, hasLength(2));
    expect(values.first.measured, isTrue);
    expect(values.first.provenance, UsageDataProvenance.androidHistory);
    expect(values.first.completeDay, isTrue);
    expect(values.last.measured, isTrue);
    expect(values.last.provenance, UsageDataProvenance.liveAndroid);
    expect(values.last.completeDay, isFalse);
  });

  test('seven-day comparison requires at least five measured days per window',
      () async {
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(granted: false),
    );
    final base = DateTime(2026, 8, 29);

    List<DailyUsageMetrics> period(int measuredCount) {
      return List.generate(7, (index) {
        final measured = index < measuredCount;
        return DailyUsageMetrics(
          day: DateTime(base.year, base.month, base.day - index),
          provenance: measured
              ? UsageDataProvenance.focusedStorage
              : UsageDataProvenance.missing,
          totalUsage: measured ? const Duration(hours: 1) : Duration.zero,
          productiveUsage: Duration.zero,
          neutralUsage: Duration.zero,
          distractingUsage: Duration.zero,
          topApps: const [],
        );
      });
    }

    expect(provider.canCompareUsagePeriods(period(5), period(5)), isTrue);
    expect(provider.canCompareUsagePeriods(period(4), period(7)), isFalse);

    final partial = period(5).toList();
    partial[4] = DailyUsageMetrics(
      day: partial[4].day,
      provenance: UsageDataProvenance.liveAndroid,
      completeDay: false,
      totalUsage: const Duration(minutes: 20),
      productiveUsage: Duration.zero,
      neutralUsage: Duration.zero,
      distractingUsage: Duration.zero,
      topApps: const [],
    );
    expect(provider.canCompareUsagePeriods(partial, period(7)), isFalse);
  });

  test('focus analysis is stored by session id for later weekly intelligence',
      () async {
    final analyses = _MemoryFocusAnalysisStore();
    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) => [
          AppUsageRecord(
            appId: 'com.instagram.android',
            appName: 'Instagram',
            startTime: start.add(const Duration(minutes: 10)),
            endTime: start.add(const Duration(minutes: 20)),
          ),
        ],
      ),
      focusAnalysisStorageService: analyses,
    );

    final start = DateTime(2026, 8, 29, 10);
    final session = FocusSession(
      id: 'persist-me',
      taskName: 'Study',
      startedAt: start,
      endedAt: start.add(const Duration(hours: 1)),
      plannedFocusDuration: const Duration(hours: 1),
      plan: const [
        FocusBlock(type: FocusBlockType.focus, duration: Duration(hours: 1)),
      ],
      focusIntervals: [
        FocusInterval(
          startTime: start,
          endTime: start.add(const Duration(hours: 1)),
        ),
      ],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );

    await provider.analyzeCompletedFocusSession(session);

    expect(provider.analysisForSession('persist-me'), isNotNull);
    expect(analyses.values.containsKey('persist-me'), isTrue);
    expect(
      provider.focusDistractedDurationForDate(start),
      const Duration(minutes: 10),
    );
    expect(provider.focusInterruptionCountForDate(start), 1);
    expect(provider.topInterrupterForRange(start, session.endedAt), 'Instagram');
  });


  test('native app metadata overrides package fallback and is cached', () async {
    final metadataStore = _MemoryAppMetadataStore();
    final metadataService = _FakeAppMetadataPlatformService(
      values: {
        'com.google.android.youtube': AppMetadata(
          packageName: 'com.google.android.youtube',
          displayName: 'YouTube',
          iconBytes: Uint8List.fromList([1, 2, 3, 4]),
          isInstalled: true,
          updatedAt: DateTime(2026, 8, 29, 12),
        ),
      },
    );

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        granted: true,
        resolver: (start, end) {
          if (start.day != 29) {
            return const [];
          }
          return [
            AppUsageRecord(
              appId: 'com.google.android.youtube',
              appName: 'com.google.android.youtube',
              startTime: DateTime(2026, 8, 29, 10),
              endTime: DateTime(2026, 8, 29, 11),
            ),
          ];
        },
      ),
      appMetadataService: metadataService,
      appMetadataStorageService: metadataStore,
    );

    await provider.refreshPermissionAndUsage(
      now: DateTime(2026, 8, 29, 12),
      force: true,
    );
    await provider.ensureAppMetadata('com.google.android.youtube');

    final top = provider.topAppEntriesToday(limit: 1);
    expect(top, hasLength(1));
    expect(top.single.appName, 'YouTube');
    expect(top.single.iconBytes, isNotNull);
    expect(top.single.iconBytes, orderedEquals([1, 2, 3, 4]));
    expect(
      metadataStore.values['com.google.android.youtube']?.displayName,
      'YouTube',
    );
  });

  test('stored app metadata can be restored without Android access', () async {
    final store = _MemoryAppMetadataStore();
    store.values['com.example.notes'] = AppMetadata(
      packageName: 'com.example.notes',
      displayName: 'Notes',
      iconBytes: Uint8List.fromList([7, 8, 9]),
      isInstalled: true,
      updatedAt: DateTime(2026, 8, 28),
    );

    final provider = UsageProvider(
      usageStatsService: _FakeUsageStatsService(
        supported: false,
        granted: false,
      ),
      appMetadataStorageService: store,
    );

    await provider.loadStoredAppMetadata();

    expect(
      provider.resolveDisplayName(
        'com.example.notes',
        fallback: 'com.example.notes',
      ),
      'Notes',
    );
    expect(
      provider.getAppMetadata('com.example.notes')?.iconBytes,
      orderedEquals([7, 8, 9]),
    );
  });
}

class _FakeUsageStatsService implements UsageStatsService {
  _FakeUsageStatsService({
    this.supported = true,
    required this.granted,
    this.throwOnQuery = false,
    this.resolver,
  });

  final bool supported;
  bool granted;
  final bool throwOnQuery;
  final List<AppUsageRecord> Function(DateTime start, DateTime end)? resolver;

  int queryCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasUsageAccess() async => granted;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  ) async {
    queryCount++;
    if (throwOnQuery) {
      throw StateError('query failed');
    }
    return resolver?.call(start, end) ?? const [];
  }
}

class _MemoryUsageStore implements UsageRecordStore {
  final Map<String, UsageDaySnapshot> _days = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> deleteDay(DateTime day) async {
    _days.remove(_key(day));
  }

  @override
  Future<UsageDaySnapshot?> loadDay(DateTime day) async {
    return _days[_key(day)];
  }

  @override
  Future<void> saveDay(
    DateTime day,
    List<AppUsageRecord> records, {
    DateTime? updatedAt,
  }) async {
    _days[_key(day)] = UsageDaySnapshot(
      day: DateTime(day.year, day.month, day.day),
      updatedAt: updatedAt ?? DateTime(2026, 8, 28, 12),
      records: List.unmodifiable(records),
    );
  }

  String _key(DateTime value) {
    return '${value.year}-${value.month}-${value.day}';
  }
}


class _MemoryCategoryStore implements AppCategoryStore {
  final Map<String, AppCategory> _values = {};

  @override
  Future<void> init() async {}

  @override
  Future<Map<String, AppCategory>> loadAll() async {
    return Map<String, AppCategory>.from(_values);
  }

  @override
  Future<void> saveCategory(
    String appId,
    AppCategory category,
  ) async {
    _values[appId] = category;
  }

  @override
  Future<void> deleteCategory(String appId) async {
    _values.remove(appId);
  }
}



class _FakeAppMetadataPlatformService implements AppMetadataPlatformService {
  _FakeAppMetadataPlatformService({
    required this.values,
    this.supported = true,
  });

  final Map<String, AppMetadata> values;
  final bool supported;

  @override
  bool get isSupported => supported;

  @override
  Future<List<AppMetadata>> loadMetadata(
    Iterable<String> packageNames, {
    int iconSize = 96,
  }) async {
    return packageNames
        .map((packageName) => values[packageName])
        .whereType<AppMetadata>()
        .toList(growable: false);
  }
}

class _MemoryAppMetadataStore implements AppMetadataStore {
  final Map<String, AppMetadata> values = {};

  @override
  Future<Map<String, AppMetadata>> loadAll() async {
    return Map<String, AppMetadata>.from(values);
  }

  @override
  Future<void> saveAll(Iterable<AppMetadata> metadata) async {
    for (final item in metadata) {
      values[item.packageName] = item;
    }
  }

  @override
  Future<void> delete(String packageName) async {
    values.remove(packageName);
  }
}


class _MemoryFocusAnalysisStore implements FocusAnalysisStore {
  final Map<String, StoredFocusAnalysis> values = {};

  @override
  Future<void> init() async {}

  @override
  List<StoredFocusAnalysis> loadAll() => values.values.toList();

  @override
  Future<void> saveAnalysis(
    String sessionId,
    FocusAnalysisResult analysis, {
    DateTime? savedAt,
  }) async {
    values[sessionId] = StoredFocusAnalysis(
      sessionId: sessionId,
      savedAt: savedAt ?? DateTime(2026, 8, 29, 12),
      analysis: analysis,
    );
  }

  @override
  Future<void> deleteAnalysis(String sessionId) async {
    values.remove(sessionId);
  }
}

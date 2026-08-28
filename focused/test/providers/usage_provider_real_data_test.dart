import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/models/usage_access_status.dart';
import 'package:focused/providers/usage_provider.dart';
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

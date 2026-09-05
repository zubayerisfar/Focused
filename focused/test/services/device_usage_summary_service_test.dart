import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/wellbeing/models/app_usage_record.dart';
import 'package:focused/features/focus/models/focus_session.dart';
import 'package:focused/features/wellbeing/services/device_usage_summary_service.dart';
import 'package:focused/features/focus/services/focus_session_storage_service.dart';
import 'package:focused/features/wellbeing/services/usage_record_storage_service.dart';

class InMemoryFocusSessionStorageService implements FocusSessionStorageService {
  final List<FocusSession> _sessions = [];

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}

  @override
  List<FocusSession> loadSessions() => List.unmodifiable(_sessions);

  @override
  Future<void> saveSession(FocusSession session) async {
    _sessions.add(session);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<void> clearAll() async {
    _sessions.clear();
  }
}

class InMemoryUsageRecordStore implements UsageRecordStore {
  final Map<DateTime, List<AppUsageRecord>> _days = {};

  @override
  Future<void> init() async {}

  @override
  Future<UsageDaySnapshot?> loadDay(DateTime day) async {
    final norm = DateTime(day.year, day.month, day.day);
    final records = _days[norm];
    if (records == null) return null;
    return UsageDaySnapshot(
      day: norm,
      updatedAt: DateTime.now(),
      records: records,
    );
  }

  @override
  Future<List<UsageDaySnapshot>> loadAllDays() async {
    final list = <UsageDaySnapshot>[];
    for (final entry in _days.entries) {
      list.add(
        UsageDaySnapshot(
          day: entry.key,
          updatedAt: DateTime.now(),
          records: entry.value,
        ),
      );
    }
    return list;
  }

  @override
  Future<void> saveDay(
    DateTime day,
    List<AppUsageRecord> records, {
    DateTime? updatedAt,
  }) async {
    final norm = DateTime(day.year, day.month, day.day);
    _days[norm] = records;
  }

  @override
  Future<void> deleteDay(DateTime day) async {
    final norm = DateTime(day.year, day.month, day.day);
    _days.remove(norm);
  }

  @override
  Future<void> clearAll() async {
    _days.clear();
  }
}

void main() {
  const summaryService = DeviceUsageSummaryService();
  late InMemoryFocusSessionStorageService focusStorage;
  late InMemoryUsageRecordStore usageStorage;

  setUp(() {
    focusStorage = InMemoryFocusSessionStorageService();
    usageStorage = InMemoryUsageRecordStore();
  });

  test('generates summary for sessions and usage records', () async {
    final day1 = DateTime(2026, 9, 1, 9);
    final day2 = DateTime(2026, 9, 2, 10);

    await focusStorage.saveSession(
      FocusSession(
        id: 's1',
        taskName: 'Deep Coding',
        startedAt: day1,
        endedAt: day1.add(const Duration(minutes: 50)),
        plannedFocusDuration: const Duration(minutes: 60),
        plan: const [],
        focusIntervals: [
          FocusInterval(
            startTime: day1,
            endTime: day1.add(const Duration(minutes: 50)),
          ),
        ],
        completedFocusBlocks: 1,
        completedNaturally: true,
      ),
    );

    await focusStorage.saveSession(
      FocusSession(
        id: 's2',
        taskName: 'Refactor',
        startedAt: day2,
        endedAt: day2.add(const Duration(minutes: 30)),
        plannedFocusDuration: const Duration(minutes: 30),
        plan: const [],
        focusIntervals: [
          FocusInterval(
            startTime: day2,
            endTime: day2.add(const Duration(minutes: 30)),
          ),
        ],
        completedFocusBlocks: 1,
        completedNaturally: true,
      ),
    );

    await usageStorage.saveDay(day1, [
      AppUsageRecord(
        appId: 'com.google.android.youtube',
        appName: 'YouTube',
        startTime: day1,
        endTime: day1.add(const Duration(minutes: 40)),
      ),
      AppUsageRecord(
        appId: 'com.android.chrome',
        appName: 'Chrome',
        startTime: day1.add(const Duration(minutes: 40)),
        endTime: day1.add(const Duration(minutes: 60)),
      ),
    ]);

    final summary = await summaryService.generateSummary(
      usageRecordStorage: usageStorage,
      focusSessionStorage: focusStorage,
    );

    expect(summary.activeDaysCount, 2);
    expect(summary.totalFocusSessions, 2);
    expect(summary.totalFocusMinutes, 80);
    expect(summary.avgDailyFocusMinutes, 40);
    expect(summary.mostDistractingApp, 'com.google.android.youtube');
    expect(summary.usualFocusTime, contains('Morning'));
  });
}

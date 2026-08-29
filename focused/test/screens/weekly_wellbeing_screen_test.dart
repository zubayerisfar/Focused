import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/models/app_usage_record.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/screens/wellbeing/weekly_wellbeing_screen.dart';
import 'package:focused/services/usage_record_storage_service.dart';
import 'package:focused/services/usage_stats_service.dart';

void main() {
  testWidgets('weekly intelligence shows coverage and daily provenance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final store = _MemoryUsageStore();

    for (var offset = 0; offset < 14; offset++) {
      final value = DateTime(day.year, day.month, day.day - offset);
      await store.saveDay(value, [
        AppUsageRecord(
          appId: 'com.example.app',
          appName: 'Example',
          startTime: DateTime(value.year, value.month, value.day, 10),
          endTime: DateTime(value.year, value.month, value.day, 11),
        ),
      ]);
    }

    final usage = UsageProvider(
      usageStatsService: _UnsupportedUsageService(),
      storageService: store,
    );
    final focus = FocusProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: usage),
          ChangeNotifierProvider.value(value: focus),
        ],
        child: const MaterialApp(home: WeeklyWellbeingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7-day intelligence'), findsOneWidget);
    expect(find.textContaining('7/7 measured'), findsOneWidget);
    expect(
      find.textContaining('Previous-period comparisons are enabled'),
      findsOneWidget,
    );

    // The daily provenance rows are below the initial phone viewport.
    // Scroll the actual ListView directly instead of using
    // scrollUntilVisible() with a target that has not been mounted yet.
    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.drag(listView, const Offset(0, -420));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Daily measurements'), findsOneWidget);
    expect(find.textContaining('Stored by Focused'), findsWidgets);
  });
}

class _UnsupportedUsageService implements UsageStatsService {
  @override
  bool get isSupported => false;

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  ) async {
    return const [];
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
      updatedAt: updatedAt ?? DateTime.now(),
      records: List<AppUsageRecord>.unmodifiable(records),
    );
  }

  String _key(DateTime value) => '${value.year}-${value.month}-${value.day}';
}

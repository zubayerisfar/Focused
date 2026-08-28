import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/services/usage_record_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('focused-usage-');
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('returns null when a day has never been measured', () async {
    final storage = UsageRecordStorageService();
    await storage.init();

    expect(await storage.loadDay(DateTime(2026, 8, 28)), isNull);
  });

  test('saves and reloads a real day snapshot', () async {
    final storage = UsageRecordStorageService();
    await storage.init();

    final updatedAt = DateTime(2026, 8, 28, 12);
    await storage.saveDay(
      DateTime(2026, 8, 28),
      [
        AppUsageRecord(
          appId: 'com.youtube',
          appName: 'YouTube',
          startTime: DateTime(2026, 8, 28, 10),
          endTime: DateTime(2026, 8, 28, 10, 20),
        ),
      ],
      updatedAt: updatedAt,
    );

    final snapshot = await storage.loadDay(DateTime(2026, 8, 28));

    expect(snapshot, isNotNull);
    expect(snapshot!.updatedAt, updatedAt);
    expect(snapshot.records, hasLength(1));
    expect(snapshot.records.single.appName, 'YouTube');
  });

  test('saving same day replaces old snapshot rather than duplicating', () async {
    final storage = UsageRecordStorageService();
    await storage.init();

    final day = DateTime(2026, 8, 28);

    await storage.saveDay(
      day,
      [
        AppUsageRecord(
          appId: 'old',
          appName: 'Old',
          startTime: DateTime(2026, 8, 28, 9),
          endTime: DateTime(2026, 8, 28, 9, 10),
        ),
      ],
    );

    await storage.saveDay(
      day,
      [
        AppUsageRecord(
          appId: 'new',
          appName: 'New',
          startTime: DateTime(2026, 8, 28, 11),
          endTime: DateTime(2026, 8, 28, 11, 15),
        ),
      ],
    );

    final snapshot = await storage.loadDay(day);
    expect(snapshot!.records, hasLength(1));
    expect(snapshot.records.single.appId, 'new');
  });

  test('an explicitly measured zero-usage day reloads as empty, not null', () async {
    final storage = UsageRecordStorageService();
    await storage.init();

    final day = DateTime(2026, 8, 28);
    await storage.saveDay(day, const []);

    final snapshot = await storage.loadDay(day);
    expect(snapshot, isNotNull);
    expect(snapshot!.records, isEmpty);
  });

  test('delete removes the day snapshot', () async {
    final storage = UsageRecordStorageService();
    await storage.init();

    final day = DateTime(2026, 8, 28);
    await storage.saveDay(day, const []);
    await storage.deleteDay(day);

    expect(await storage.loadDay(day), isNull);
  });
}

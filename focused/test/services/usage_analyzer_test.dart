import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/app_usage_record.dart';
import 'package:focused/services/usage_analyzer.dart';

void main() {
  late UsageAnalyzer analyzer;

  setUp(() {
    analyzer = UsageAnalyzer();
  });

  final testDay = DateTime(2026, 8, 27);

  DateTime time(int hour, int minute, [int second = 0]) {
    return DateTime(2026, 8, 27, hour, minute, second);
  }

  AppUsageRecord record({
    required String app,
    required DateTime start,
    required DateTime end,
  }) {
    return AppUsageRecord(
      appId: app.toLowerCase(),
      appName: app,
      startTime: start,
      endTime: end,
    );
  }

  test('empty day has zero usage', () {
    final summary = analyzer.buildDailySummary(testDay, []);

    expect(summary.totalUsage, Duration.zero);

    expect(summary.appUsage, isEmpty);

    // Normal non-DST test date.
    expect(summary.hourlyUsage.length, 24);
  });

  test('single record is counted correctly', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(10, 0), end: time(10, 30)),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 30));

    expect(summary.appUsage['Instagram'], const Duration(minutes: 30));
  });

  test('record crossing an hour is split correctly', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(8, 50), end: time(9, 20)),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 30));

    expect(summary.hourlyUsage[8].totalUsage, const Duration(minutes: 10));

    expect(summary.hourlyUsage[9].totalUsage, const Duration(minutes: 20));

    expect(
      summary.hourlyUsage[8].appUsage['Instagram'],
      const Duration(minutes: 10),
    );

    expect(
      summary.hourlyUsage[9].appUsage['Instagram'],
      const Duration(minutes: 20),
    );
  });

  test('record beginning yesterday is clipped at midnight', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(
        app: 'YouTube',
        start: DateTime(2026, 8, 26, 23, 50),
        end: time(0, 10),
      ),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 10));

    expect(summary.hourlyUsage.first.totalUsage, const Duration(minutes: 10));
  });

  test('record ending tomorrow is clipped at midnight', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(
        app: 'YouTube',
        start: time(23, 50),
        end: DateTime(2026, 8, 28, 0, 10),
      ),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 10));

    expect(summary.hourlyUsage.last.totalUsage, const Duration(minutes: 10));
  });

  test('records completely outside the day are ignored', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(
        app: 'Instagram',
        start: DateTime(2026, 8, 26, 10),
        end: DateTime(2026, 8, 26, 11),
      ),
    ]);

    expect(summary.totalUsage, Duration.zero);

    expect(summary.appUsage, isEmpty);
  });

  test('zero and negative duration records are ignored', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(10, 0), end: time(10, 0)),
      record(app: 'YouTube', start: time(11, 0), end: time(10, 0)),
    ]);

    expect(summary.totalUsage, Duration.zero);

    expect(summary.appUsage, isEmpty);
  });

  test('duplicate overlapping records for same app are merged', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(10, 0), end: time(10, 20)),
      record(app: 'Instagram', start: time(10, 10), end: time(10, 30)),
    ]);

    expect(summary.appUsage['Instagram'], const Duration(minutes: 30));

    expect(summary.totalUsage, const Duration(minutes: 30));
  });

  test('overlapping different apps do not inflate total screen time', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(10, 0), end: time(10, 20)),
      record(app: 'WhatsApp', start: time(10, 10), end: time(10, 30)),
    ]);

    expect(summary.appUsage['Instagram'], const Duration(minutes: 20));

    expect(summary.appUsage['WhatsApp'], const Duration(minutes: 20));

    // 10:00 → 10:30 is only 30 real minutes.
    expect(summary.totalUsage, const Duration(minutes: 30));

    expect(summary.hourlyUsage[10].totalUsage, const Duration(minutes: 30));
  });

  test('touching records form continuous usage without double counting', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Instagram', start: time(10, 0), end: time(10, 10)),
      record(app: 'Instagram', start: time(10, 10), end: time(10, 20)),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 20));

    expect(summary.appUsage['Instagram'], const Duration(minutes: 20));
  });

  test('long usage spanning several hours produces correct buckets', () {
    final summary = analyzer.buildDailySummary(testDay, [
      record(app: 'Chrome', start: time(8, 30), end: time(11, 15)),
    ]);

    expect(summary.totalUsage, const Duration(hours: 2, minutes: 45));

    expect(summary.hourlyUsage[8].totalUsage, const Duration(minutes: 30));

    expect(summary.hourlyUsage[9].totalUsage, const Duration(hours: 1));

    expect(summary.hourlyUsage[10].totalUsage, const Duration(hours: 1));

    expect(summary.hourlyUsage[11].totalUsage, const Duration(minutes: 15));
  });

  test(
    'fully overlapping full-day records cannot create more than one day of screen time',
    () {
      final nextDay = DateTime(2026, 8, 28);

      final summary = analyzer.buildDailySummary(testDay, [
        record(app: 'App A', start: testDay, end: nextDay),
        record(app: 'App B', start: testDay, end: nextDay),
      ]);

      expect(summary.totalUsage, const Duration(hours: 24));

      // Each individual app was reported for 24h.
      expect(summary.appUsage['App A'], const Duration(hours: 24));

      expect(summary.appUsage['App B'], const Duration(hours: 24));

      // But real elapsed screen time is still only 24h.
      expect(summary.totalUsage.inHours <= 24, isTrue);
    },
  );
}

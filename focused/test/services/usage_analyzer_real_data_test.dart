import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/services/usage_analyzer.dart';

void main() {
  final analyzer = UsageAnalyzer();

  test('total usage is unioned across overlapping apps', () {
    final day = DateTime(2026, 8, 28);
    final summary = analyzer.buildDailySummary(day, [
      AppUsageRecord(
        appId: 'a',
        appName: 'A',
        startTime: DateTime(2026, 8, 28, 10),
        endTime: DateTime(2026, 8, 28, 11),
      ),
      AppUsageRecord(
        appId: 'b',
        appName: 'B',
        startTime: DateTime(2026, 8, 28, 10, 30),
        endTime: DateTime(2026, 8, 28, 11, 30),
      ),
    ]);

    expect(summary.totalUsage, const Duration(hours: 1, minutes: 30));
    expect(summary.appUsage['A'], const Duration(hours: 1));
    expect(summary.appUsage['B'], const Duration(hours: 1));
  });

  test('duplicate same-app intervals do not inflate app usage', () {
    final summary = analyzer.buildDailySummary(DateTime(2026, 8, 28), [
      AppUsageRecord(
        appId: 'a',
        appName: 'A',
        startTime: DateTime(2026, 8, 28, 10),
        endTime: DateTime(2026, 8, 28, 11),
      ),
      AppUsageRecord(
        appId: 'a',
        appName: 'A',
        startTime: DateTime(2026, 8, 28, 10, 15),
        endTime: DateTime(2026, 8, 28, 10, 45),
      ),
    ]);

    expect(summary.appUsage['A'], const Duration(hours: 1));
    expect(summary.totalUsage, const Duration(hours: 1));
  });

  test('cross-midnight record is clipped to selected day', () {
    final summary = analyzer.buildDailySummary(DateTime(2026, 8, 28), [
      AppUsageRecord(
        appId: 'a',
        appName: 'A',
        startTime: DateTime(2026, 8, 27, 23, 50),
        endTime: DateTime(2026, 8, 28, 0, 20),
      ),
    ]);

    expect(summary.totalUsage, const Duration(minutes: 20));
  });

  test('usage crossing an hour is split between hourly buckets', () {
    final summary = analyzer.buildDailySummary(DateTime(2026, 8, 28), [
      AppUsageRecord(
        appId: 'a',
        appName: 'A',
        startTime: DateTime(2026, 8, 28, 10, 50),
        endTime: DateTime(2026, 8, 28, 11, 10),
      ),
    ]);

    final ten = summary.hourlyUsage.firstWhere((h) => h.hourStart.hour == 10);
    final eleven = summary.hourlyUsage.firstWhere((h) => h.hourStart.hour == 11);

    expect(ten.totalUsage, const Duration(minutes: 10));
    expect(eleven.totalUsage, const Duration(minutes: 10));
  });
}

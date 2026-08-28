import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_category.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/services/focus_interruption_analyzer.dart';

void main() {
  test('real Android package id can drive distraction classification', () {
    final analyzer = FocusInterruptionAnalyzer();
    final start = DateTime(2026, 8, 28, 10);
    final end = DateTime(2026, 8, 28, 11);

    final session = FocusSession(
      id: 'session',
      taskId: 'task',
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

    final result = analyzer.analyzeSession(
      session: session,
      usageRecords: [
        AppUsageRecord(
          appId: 'com.instagram.android',
          appName: 'Instagram',
          startTime: DateTime(2026, 8, 28, 10, 15),
          endTime: DateTime(2026, 8, 28, 10, 25),
        ),
      ],
      appCategories: const {
        'com.instagram.android': AppCategory.distracting,
      },
    );

    expect(result.distractedDuration, const Duration(minutes: 10));
    expect(result.effectiveFocusDuration, const Duration(minutes: 50));
    expect(result.interruptionCount, 1);
    expect(result.topInterrupterApp, 'Instagram');
    expect(result.focusQuality.round(), 83);
  });

  test('unknown real package remains neutral by default', () {
    final analyzer = FocusInterruptionAnalyzer();
    final start = DateTime(2026, 8, 28, 10);
    final end = DateTime(2026, 8, 28, 11);

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

    final result = analyzer.analyzeSession(
      session: session,
      usageRecords: [
        AppUsageRecord(
          appId: 'com.unknown.app',
          appName: 'Unknown',
          startTime: DateTime(2026, 8, 28, 10, 15),
          endTime: DateTime(2026, 8, 28, 10, 25),
        ),
      ],
      appCategories: const {},
    );

    expect(result.distractedDuration, Duration.zero);
    expect(result.effectiveFocusDuration, const Duration(hours: 1));
    expect(result.focusQuality, 100);
  });
}

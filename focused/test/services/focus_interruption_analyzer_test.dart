import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/app_category.dart';
import 'package:focused/models/app_usage_record.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/services/focus_interruption_analyzer.dart';

void main() {
  late FocusInterruptionAnalyzer analyzer;

  const categories = {
    'Instagram': AppCategory.distracting,
    'WhatsApp': AppCategory.distracting,
    'YouTube': AppCategory.distracting,
    'VS Code': AppCategory.productive,
    'Chrome': AppCategory.neutral,
  };

  setUp(() {
    analyzer = FocusInterruptionAnalyzer();
  });

  DateTime time(int hour, int minute, [int second = 0]) {
    return DateTime(2026, 8, 27, hour, minute, second);
  }

  FocusSession session({
    required int plannedMinutes,
    required List<FocusInterval> intervals,
  }) {
    final start = intervals.first.startTime;

    final end = intervals.last.endTime;

    return FocusSession(
      id: 'test-session',
      taskName: 'Test',
      startedAt: start,
      endedAt: end,
      plannedFocusDuration: Duration(minutes: plannedMinutes),
      plan: [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(minutes: plannedMinutes),
        ),
      ],
      focusIntervals: intervals,
      completedFocusBlocks: 1,
      completedNaturally: true,
    );
  }

  test('completed session with no distraction gives 100% quality', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: [],
      appCategories: categories,
    );

    expect(result.actualFocusDuration, const Duration(minutes: 60));

    expect(result.distractedDuration, Duration.zero);

    expect(result.effectiveFocusDuration, const Duration(minutes: 60));

    expect(result.completionRate, 100);

    expect(result.attentionRetention, 100);

    expect(result.focusQuality, 100);
  });

  test('app already open before focus only counts overlapping portion', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(9, 55),
        endTime: time(10, 5),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, const Duration(minutes: 5));

    expect(result.effectiveFocusDuration, const Duration(minutes: 55));
  });

  test('usage during a break is ignored', () {
    final testSession = session(
      plannedMinutes: 80,
      intervals: [
        FocusInterval(startTime: time(10, 0), endTime: time(10, 50)),
        FocusInterval(startTime: time(11, 0), endTime: time(11, 30)),
      ],
    );

    final records = [
      AppUsageRecord(
        appId: 'youtube',
        appName: 'YouTube',
        startTime: time(10, 52),
        endTime: time(10, 58),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, Duration.zero);

    expect(result.interruptionCount, 0);
  });

  test('overlapping distraction intervals are not double counted', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(10, 10),
        endTime: time(10, 20),
      ),
      AppUsageRecord(
        appId: 'whatsapp',
        appName: 'WhatsApp',
        startTime: time(10, 15),
        endTime: time(10, 25),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    // 10:10 -> 10:25 = 15 unique minutes.
    expect(result.distractedDuration, const Duration(minutes: 15));

    expect(result.interruptionCount, 1);

    expect(result.effectiveFocusDuration, const Duration(minutes: 45));
  });

  test('ending early reduces completion but not attention retention', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(10, 30))],
    );

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: [],
      appCategories: categories,
    );

    expect(result.completionRate, 50);

    expect(result.attentionRetention, 100);

    expect(result.focusQuality, 50);
  });

  test('usage while focus timer is paused is ignored', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [
        FocusInterval(startTime: time(10, 0), endTime: time(10, 20)),
        FocusInterval(startTime: time(10, 30), endTime: time(11, 10)),
      ],
    );

    final records = [
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(10, 24),
        endTime: time(10, 28),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, Duration.zero);

    expect(result.focusQuality, 100);
  });

  test('neutral and productive apps do not count as distractions', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'vscode',
        appName: 'VS Code',
        startTime: time(10, 5),
        endTime: time(10, 25),
      ),
      AppUsageRecord(
        appId: 'chrome',
        appName: 'Chrome',
        startTime: time(10, 30),
        endTime: time(10, 40),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, Duration.zero);
  });

  test('unknown apps default to neutral', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'unknown',
        appName: 'Unknown App',
        startTime: time(10, 0),
        endTime: time(11, 0),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, Duration.zero);
  });

  test('duplicate overlapping records from same app are merged', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(10, 10),
        endTime: time(10, 20),
      ),
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(10, 15),
        endTime: time(10, 25),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.distractedDuration, const Duration(minutes: 15));

    expect(result.distractionByApp['Instagram'], const Duration(minutes: 15));
  });

  test('fully distracted focus gives zero effective focus', () {
    final testSession = session(
      plannedMinutes: 60,
      intervals: [FocusInterval(startTime: time(10, 0), endTime: time(11, 0))],
    );

    final records = [
      AppUsageRecord(
        appId: 'instagram',
        appName: 'Instagram',
        startTime: time(10, 0),
        endTime: time(11, 0),
      ),
    ];

    final result = analyzer.analyzeSession(
      session: testSession,
      usageRecords: records,
      appCategories: categories,
    );

    expect(result.effectiveFocusDuration, Duration.zero);

    expect(result.attentionRetention, 0);

    expect(result.focusQuality, 0);
  });
}

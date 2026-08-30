import 'package:flutter_test/flutter_test.dart';

import 'package:focused/models/focus_analysis_result.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_interruption.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/models/task.dart';
import 'package:focused/models/task_occurrence.dart';
import 'package:focused/services/task_execution_analyzer.dart';

void main() {
  const analyzer = TaskExecutionAnalyzer();

  Task buildTask() {
    return Task(
      id: 'task-1',
      title: 'Research',
      priority: TaskPriority.important,
      scheduledStart: DateTime(2026, 8, 29, 10),
      scheduledEnd: DateTime(2026, 8, 29, 11, 30),
      createdAt: DateTime(2026, 8, 1),
    );
  }

  FocusSession session({
    required String id,
    required DateTime startedAt,
    required DateTime endedAt,
    required DateTime focusStart,
    required DateTime focusEnd,
  }) {
    return FocusSession(
      id: id,
      taskId: 'task-1',
      taskName: 'Research',
      taskOccurrenceDate: DateTime(2026, 8, 29),
      taskScheduledStart: DateTime(2026, 8, 29, 10),
      taskScheduledEnd: DateTime(2026, 8, 29, 11, 30),
      startedAt: startedAt,
      endedAt: endedAt,
      plannedFocusDuration: focusEnd.difference(focusStart),
      plan: [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: focusEnd.difference(focusStart),
        ),
      ],
      focusIntervals: [
        FocusInterval(startTime: focusStart, endTime: focusEnd),
      ],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );
  }

  FocusAnalysisResult analysis({
    required DateTime start,
    required DateTime end,
    required DateTime distractionStart,
    required DateTime distractionEnd,
  }) {
    final actual = end.difference(start);
    final distracted = distractionEnd.difference(distractionStart);
    final effective = actual - distracted;
    return FocusAnalysisResult(
      focusStart: start,
      focusEnd: end,
      plannedDuration: actual,
      actualFocusDuration: actual,
      distractedDuration: distracted,
      effectiveFocusDuration: effective,
      interruptionCount: 1,
      completionRate: 100,
      attentionRetention: effective.inSeconds / actual.inSeconds * 100,
      focusQuality: effective.inSeconds / actual.inSeconds * 100,
      topInterrupterApp: 'com.google.android.youtube',
      distractionByApp: {
        'com.google.android.youtube': distracted,
      },
      interruptions: [
        FocusInterruption(
          appId: 'com.google.android.youtube',
          appName: 'YouTube',
          startTime: distractionStart,
          endTime: distractionEnd,
        ),
      ],
    );
  }

  test('combines multiple sessions for one occurrence without double counting', () {
    final task = buildTask();
    final occurrence = TaskOccurrence(
      task: task,
      start: DateTime(2026, 8, 29, 10),
      end: DateTime(2026, 8, 29, 11, 30),
    );
    final first = session(
      id: 's1',
      startedAt: DateTime(2026, 8, 29, 10, 18),
      endedAt: DateTime(2026, 8, 29, 10, 48),
      focusStart: DateTime(2026, 8, 29, 10, 18),
      focusEnd: DateTime(2026, 8, 29, 10, 48),
    );
    final second = session(
      id: 's2',
      startedAt: DateTime(2026, 8, 29, 11, 3),
      endedAt: DateTime(2026, 8, 29, 11, 36),
      focusStart: DateTime(2026, 8, 29, 11, 3),
      focusEnd: DateTime(2026, 8, 29, 11, 36),
    );

    final result = analyzer.summarizeOccurrence(
      occurrence: occurrence,
      sessions: [first, second],
      analysesBySessionId: {
        's1': analysis(
          start: first.startedAt,
          end: first.endedAt,
          distractionStart: DateTime(2026, 8, 29, 10, 25),
          distractionEnd: DateTime(2026, 8, 29, 10, 30),
        ),
        's2': analysis(
          start: second.startedAt,
          end: second.endedAt,
          distractionStart: DateTime(2026, 8, 29, 11, 10),
          distractionEnd: DateTime(2026, 8, 29, 11, 14),
        ),
      },
    );

    expect(result.actualStart, DateTime(2026, 8, 29, 10, 18));
    expect(result.actualEnd, DateTime(2026, 8, 29, 11, 36));
    expect(result.startDelay, const Duration(minutes: 18));
    expect(result.activeFocusDuration, const Duration(minutes: 63));
    expect(result.distractedDuration, const Duration(minutes: 9));
    expect(result.effectiveFocusDuration, const Duration(minutes: 54));
    expect(result.interruptionCount, 2);
    expect(result.topInterrupterApp, 'com.google.android.youtube');
    expect(result.sessionCount, 2);
    expect(result.planCoveragePercent.round(), 70);
    expect(result.effectiveCoveragePercent!.round(), 60);
  });

  test('schedule snapshot wins over a later task schedule edit', () {
    final editedTask = Task(
      id: 'task-1',
      title: 'Research',
      priority: TaskPriority.important,
      scheduledStart: DateTime(2026, 8, 29, 12),
      scheduledEnd: DateTime(2026, 8, 29, 13, 30),
      createdAt: DateTime(2026, 8, 1),
    );
    final occurrence = TaskOccurrence(
      task: editedTask,
      start: DateTime(2026, 8, 29, 12),
      end: DateTime(2026, 8, 29, 13, 30),
    );
    final originalSession = session(
      id: 'snapshot',
      startedAt: DateTime(2026, 8, 29, 10, 18),
      endedAt: DateTime(2026, 8, 29, 10, 48),
      focusStart: DateTime(2026, 8, 29, 10, 18),
      focusEnd: DateTime(2026, 8, 29, 10, 48),
    );

    final result = analyzer.summarizeOccurrence(
      occurrence: occurrence,
      sessions: [originalSession],
      analysesBySessionId: {
        'snapshot': analysis(
          start: originalSession.startedAt,
          end: originalSession.endedAt,
          distractionStart: DateTime(2026, 8, 29, 10, 25),
          distractionEnd: DateTime(2026, 8, 29, 10, 30),
        ),
      },
    );

    expect(result.plannedStart, DateTime(2026, 8, 29, 10));
    expect(result.plannedEnd, DateTime(2026, 8, 29, 11, 30));
    expect(result.startDelay, const Duration(minutes: 18));
  });

  test('partial-day period does not penalize tasks scheduled for later', () {
    final task = buildTask();
    final morning = TaskOccurrence(
      task: task,
      start: DateTime(2026, 8, 29, 10),
      end: DateTime(2026, 8, 29, 11, 30),
    );
    final laterTask = Task(
      id: 'task-2',
      title: 'Evening work',
      priority: TaskPriority.growth,
      scheduledStart: DateTime(2026, 8, 29, 18),
      scheduledEnd: DateTime(2026, 8, 29, 19),
      createdAt: DateTime(2026, 8, 1),
    );
    final evening = TaskOccurrence(
      task: laterTask,
      start: DateTime(2026, 8, 29, 18),
      end: DateTime(2026, 8, 29, 19),
    );
    final first = session(
      id: 'morning',
      startedAt: DateTime(2026, 8, 29, 10, 4),
      endedAt: DateTime(2026, 8, 29, 10, 34),
      focusStart: DateTime(2026, 8, 29, 10, 4),
      focusEnd: DateTime(2026, 8, 29, 10, 34),
    );

    final period = analyzer.summarizePeriod(
      startDay: DateTime(2026, 8, 29),
      endDay: DateTime(2026, 8, 30),
      occurrences: [morning, evening],
      sessions: [first],
      analysesBySessionId: {
        'morning': analysis(
          start: first.startedAt,
          end: first.endedAt,
          distractionStart: DateTime(2026, 8, 29, 10, 20),
          distractionEnd: DateTime(2026, 8, 29, 10, 22),
        ),
      },
      asOf: DateTime(2026, 8, 29, 12),
    );

    expect(period.scheduledCount, 2);
    expect(period.startEligibleCount, 1);
    expect(period.startedCount, 1);
    expect(period.startRatePercent, 100);
    expect(period.completionEligibleCount, 1);
  });

  test('active session marks occurrence active and withholds effective focus', () {
    final task = buildTask();
    final occurrence = TaskOccurrence(
      task: task,
      start: DateTime(2026, 8, 29, 10),
      end: DateTime(2026, 8, 29, 11, 30),
    );

    final result = analyzer.summarizeOccurrence(
      occurrence: occurrence,
      sessions: const [],
      analysesBySessionId: const {},
      activeTaskId: 'task-1',
      activeOccurrenceDate: DateTime(2026, 8, 29),
      activeSessionStartedAt: DateTime(2026, 8, 29, 10, 7),
      activeTaskScheduledStart: DateTime(2026, 8, 29, 10),
      activeTaskScheduledEnd: DateTime(2026, 8, 29, 11, 30),
      activeFocusIntervals: [
        FocusInterval(
          startTime: DateTime(2026, 8, 29, 10, 7),
          endTime: DateTime(2026, 8, 29, 10, 27),
        ),
      ],
    );

    expect(result.isActive, isTrue);
    expect(result.startDelay, const Duration(minutes: 7));
    expect(result.activeFocusDuration, const Duration(minutes: 20));
    expect(result.focusAnalysisComplete, isFalse);
    expect(result.effectiveFocusDuration, isNull);
  });
}

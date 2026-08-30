import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';

void main() {
  FocusSession buildSession() {
    final startedAt = DateTime(2026, 8, 28, 9);
    final endedAt = DateTime(2026, 8, 28, 10, 20);

    return FocusSession(
      id: 'session-1',
      taskId: 'task-1',
      taskName: 'Study Flutter',
      taskOccurrenceDate: DateTime(2026, 8, 28),
      taskScheduledStart: DateTime(2026, 8, 28, 9),
      taskScheduledEnd: DateTime(2026, 8, 28, 10),
      startedAt: startedAt,
      endedAt: endedAt,
      plannedFocusDuration: const Duration(hours: 1),
      plan: const [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(minutes: 30),
        ),
        FocusBlock(
          type: FocusBlockType.breakTime,
          duration: Duration(minutes: 10),
        ),
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(minutes: 30),
        ),
      ],
      focusIntervals: [
        FocusInterval(
          startTime: startedAt,
          endTime: DateTime(2026, 8, 28, 9, 20),
        ),
        FocusInterval(
          startTime: DateTime(2026, 8, 28, 9, 25),
          endTime: DateTime(2026, 8, 28, 9, 30),
        ),
        FocusInterval(
          startTime: DateTime(2026, 8, 28, 9, 40),
          endTime: DateTime(2026, 8, 28, 10, 10),
        ),
      ],
      pauseIntervals: [
        FocusInterval(
          startTime: DateTime(2026, 8, 28, 9, 20),
          endTime: DateTime(2026, 8, 28, 9, 25),
        ),
      ],
      breakIntervals: [
        FocusInterval(
          startTime: DateTime(2026, 8, 28, 9, 30),
          endTime: DateTime(2026, 8, 28, 9, 40),
        ),
      ],
      completedFocusBlocks: 1,
      completedNaturally: false,
    );
  }

  test('computes focus, pause, break, and elapsed durations', () {
    final session = buildSession();

    expect(
      session.actualFocusDuration,
      const Duration(minutes: 55),
    );
    expect(
      session.pausedDuration,
      const Duration(minutes: 5),
    );
    expect(
      session.breakDuration,
      const Duration(minutes: 10),
    );
    expect(
      session.totalElapsedDuration,
      const Duration(minutes: 80),
    );
    expect(session.totalFocusBlocks, 2);
  });

  test('round-trips the complete persistent session schema', () {
    final original = buildSession();

    final restored = FocusSession.fromMap(
      original.toMap(),
    );

    expect(restored.id, original.id);
    expect(restored.taskId, original.taskId);
    expect(restored.taskName, original.taskName);
    expect(restored.taskOccurrenceDate, DateTime(2026, 8, 28));
    expect(restored.taskScheduledStart, DateTime(2026, 8, 28, 9));
    expect(restored.taskScheduledEnd, DateTime(2026, 8, 28, 10));
    expect(restored.linkedOccurrenceDate, DateTime(2026, 8, 28));
    expect(restored.startedAt, original.startedAt);
    expect(restored.endedAt, original.endedAt);
    expect(
      restored.plannedFocusDuration,
      original.plannedFocusDuration,
    );
    expect(restored.plan.length, 3);
    expect(restored.plan[0].type, FocusBlockType.focus);
    expect(
      restored.plan[1].type,
      FocusBlockType.breakTime,
    );
    expect(restored.focusIntervals.length, 3);
    expect(restored.pauseIntervals.length, 1);
    expect(restored.breakIntervals.length, 1);
    expect(restored.completedFocusBlocks, 1);
    expect(restored.completedNaturally, isFalse);
    expect(
      restored.actualFocusDuration,
      const Duration(minutes: 55),
    );
  });

  test('schema-v1 history remains readable and falls back to session day', () {
    final map = buildSession().toMap();
    map['schemaVersion'] = 1;
    map.remove('taskOccurrenceDate');
    map.remove('taskScheduledStart');
    map.remove('taskScheduledEnd');

    final restored = FocusSession.fromMap(map);

    expect(restored.taskOccurrenceDate, isNull);
    expect(restored.taskScheduledStart, isNull);
    expect(restored.taskScheduledEnd, isNull);
    expect(restored.linkedOccurrenceDate, DateTime(2026, 8, 28));
  });

  test('rejects an interval whose end is not after its start', () {
    final now = DateTime(2026, 8, 28, 9);

    expect(
      () => FocusInterval.fromMap({
        'startTime': now.toIso8601String(),
        'endTime': now.toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test('rejects a session with more completed blocks than planned', () {
    final map = buildSession().toMap();
    map['completedFocusBlocks'] = 3;

    expect(
      () => FocusSession.fromMap(map),
      throwsFormatException,
    );
  });
}

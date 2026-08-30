import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/services/focus_session_storage_service.dart';

void main() {
  late Directory tempDirectory;
  late FocusSessionStorageService storage;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused-focus-provider-',
    );

    Hive.init(tempDirectory.path);

    storage = FocusSessionStorageService();
    await storage.init();
  });

  tearDown(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  FocusSession storedSession({
    required String id,
    required DateTime startedAt,
    required DateTime endedAt,
    required List<FocusInterval> focusIntervals,
  }) {
    return FocusSession(
      id: id,
      taskId: 'task-$id',
      taskName: 'Task $id',
      startedAt: startedAt,
      endedAt: endedAt,
      plannedFocusDuration: const Duration(hours: 1),
      plan: const [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(hours: 1),
        ),
      ],
      focusIntervals: focusIntervals,
      pauseIntervals: const [],
      breakIntervals: const [],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );
  }

  test('loads persisted history with newest session first', () async {
    await storage.saveSession(
      storedSession(
        id: 'older',
        startedAt: DateTime(2026, 8, 28, 8),
        endedAt: DateTime(2026, 8, 28, 9),
        focusIntervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 8),
            endTime: DateTime(2026, 8, 28, 9),
          ),
        ],
      ),
    );

    await storage.saveSession(
      storedSession(
        id: 'newer',
        startedAt: DateTime(2026, 8, 28, 10),
        endedAt: DateTime(2026, 8, 28, 11),
        focusIntervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 10),
            endTime: DateTime(2026, 8, 28, 11),
          ),
        ],
      ),
    );

    final provider = FocusProvider(
      storageService: storage,
    );

    await provider.loadStoredSessions();

    expect(provider.sessionHistory, hasLength(2));
    expect(provider.latestSession!.id, 'newer');
  });

  test('daily focus total clips midnight and unions overlaps', () async {
    await storage.saveSession(
      storedSession(
        id: 'overnight',
        startedAt: DateTime(2026, 8, 27, 23, 50),
        endedAt: DateTime(2026, 8, 28, 0, 10),
        focusIntervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 27, 23, 50),
            endTime: DateTime(2026, 8, 28, 0, 10),
          ),
        ],
      ),
    );

    await storage.saveSession(
      storedSession(
        id: 'overlap',
        startedAt: DateTime(2026, 8, 28, 0, 5),
        endedAt: DateTime(2026, 8, 28, 0, 15),
        focusIntervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 0, 5),
            endTime: DateTime(2026, 8, 28, 0, 15),
          ),
        ],
      ),
    );

    final provider = FocusProvider(
      storageService: storage,
    );

    await provider.loadStoredSessions();

    expect(
      provider.focusedDurationForDate(
        DateTime(2026, 8, 27),
      ),
      const Duration(minutes: 10),
    );

    expect(
      provider.focusedDurationForDate(
        DateTime(2026, 8, 28),
      ),
      const Duration(minutes: 15),
    );

    expect(
      provider.sessionCountForDate(
        DateTime(2026, 8, 28),
      ),
      2,
    );
  });

  test('ending a session persists task snapshot and active focus', () async {
    var now = DateTime(2026, 8, 28, 9);

    final provider = FocusProvider(
      storageService: storage,
      now: () => now,
    );

    provider.startSession(
      taskId: 'task-1',
      taskName: 'Study Flutter',
      taskOccurrenceDate: DateTime(2026, 8, 28),
      taskScheduledStart: DateTime(2026, 8, 28, 8, 45),
      taskScheduledEnd: DateTime(2026, 8, 28, 9, 45),
      totalFocusMinutes: 30,
      focusBlockMinutes: 30,
      breakMinutes: 5,
    );

    now = DateTime(2026, 8, 28, 9, 12);

    expect(
      provider.isFocusingTaskOccurrence(
        'task-1',
        DateTime(2026, 8, 28),
      ),
      isTrue,
    );
    expect(
      provider.currentActiveFocusDuration,
      const Duration(minutes: 12),
    );

    provider.endSession();

    await provider.flushPendingPersistence();

    final finished = provider.lastSession;

    expect(finished, isNotNull);
    expect(finished!.taskId, 'task-1');
    expect(finished.taskName, 'Study Flutter');
    expect(finished.taskOccurrenceDate, DateTime(2026, 8, 28));
    expect(finished.taskScheduledStart, DateTime(2026, 8, 28, 8, 45));
    expect(finished.taskScheduledEnd, DateTime(2026, 8, 28, 9, 45));
    expect(
      finished.actualFocusDuration,
      const Duration(minutes: 12),
    );
    expect(finished.completedNaturally, isFalse);

    final reloaded = FocusProvider(
      storageService: storage,
    );

    await reloaded.loadStoredSessions();

    expect(reloaded.sessionHistory, hasLength(1));
    expect(
      reloaded.sessionHistory.single.actualFocusDuration,
      const Duration(minutes: 12),
    );
  });

  test('pause and resume create separate focus and pause intervals', () async {
    var now = DateTime(2026, 8, 28, 9);

    final provider = FocusProvider(
      storageService: storage,
      now: () => now,
    );

    provider.startSession(
      taskId: 'task-1',
      taskName: 'Study',
      totalFocusMinutes: 30,
      focusBlockMinutes: 30,
      breakMinutes: 5,
    );

    now = DateTime(2026, 8, 28, 9, 10);
    provider.pauseSession();

    now = DateTime(2026, 8, 28, 9, 15);
    provider.resumeSession();

    now = DateTime(2026, 8, 28, 9, 23);
    provider.endSession();

    await provider.flushPendingPersistence();

    final session = provider.lastSession!;

    expect(session.focusIntervals, hasLength(2));
    expect(session.pauseIntervals, hasLength(1));
    expect(
      session.actualFocusDuration,
      const Duration(minutes: 18),
    );
    expect(
      session.pausedDuration,
      const Duration(minutes: 5),
    );
    expect(
      session.totalElapsedDuration,
      const Duration(minutes: 23),
    );
  });

  test('cannot silently replace an already running session', () async {
    final provider = FocusProvider(
      storageService: storage,
      now: () => DateTime(2026, 8, 28, 9),
    );

    provider.startSession(
      taskId: 'task-1',
      taskName: 'First',
      totalFocusMinutes: 30,
      focusBlockMinutes: 30,
      breakMinutes: 5,
    );

    expect(
      () => provider.startSession(
        taskId: 'task-2',
        taskName: 'Second',
        totalFocusMinutes: 30,
        focusBlockMinutes: 30,
        breakMinutes: 5,
      ),
      throwsStateError,
    );

    provider.endSession();
    await provider.flushPendingPersistence();
  });
}

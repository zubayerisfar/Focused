import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_session.dart';
import 'package:focused/services/focus_session_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused-focus-history-',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  FocusSession session({
    required String id,
    required DateTime startedAt,
    String taskName = 'Study',
  }) {
    return FocusSession(
      id: id,
      taskId: 'task-$id',
      taskName: taskName,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 30)),
      plannedFocusDuration: const Duration(minutes: 30),
      plan: const [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(minutes: 30),
        ),
      ],
      focusIntervals: [
        FocusInterval(
          startTime: startedAt,
          endTime: startedAt.add(const Duration(minutes: 30)),
        ),
      ],
      pauseIntervals: const [],
      breakIntervals: const [],
      completedFocusBlocks: 1,
      completedNaturally: true,
    );
  }

  test('saves and reloads focus session history', () async {
    final storage = FocusSessionStorageService();
    await storage.init();

    final value = session(
      id: 'one',
      startedAt: DateTime(2026, 8, 28, 9),
    );

    await storage.saveSession(value);

    final loaded = storage.loadSessions();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'one');
    expect(loaded.single.taskName, 'Study');
    expect(
      loaded.single.actualFocusDuration,
      const Duration(minutes: 30),
    );
  });

  test('load order is newest session first', () async {
    final storage = FocusSessionStorageService();
    await storage.init();

    await storage.saveSession(
      session(
        id: 'older',
        startedAt: DateTime(2026, 8, 28, 9),
      ),
    );
    await storage.saveSession(
      session(
        id: 'newer',
        startedAt: DateTime(2026, 8, 28, 11),
      ),
    );

    final loaded = storage.loadSessions();

    expect(
      loaded.map((item) => item.id).toList(),
      ['newer', 'older'],
    );
  });

  test('saving the same session id does not create duplicates', () async {
    final storage = FocusSessionStorageService();
    await storage.init();

    final first = session(
      id: 'same',
      startedAt: DateTime(2026, 8, 28, 9),
      taskName: 'Original',
    );
    final updated = FocusSession(
      id: first.id,
      taskId: first.taskId,
      taskName: 'Updated snapshot',
      startedAt: first.startedAt,
      endedAt: first.endedAt,
      plannedFocusDuration: first.plannedFocusDuration,
      plan: first.plan,
      focusIntervals: first.focusIntervals,
      pauseIntervals: first.pauseIntervals,
      breakIntervals: first.breakIntervals,
      completedFocusBlocks: first.completedFocusBlocks,
      completedNaturally: first.completedNaturally,
    );

    await storage.saveSession(first);
    await storage.saveSession(updated);

    final loaded = storage.loadSessions();

    expect(loaded, hasLength(1));
    expect(loaded.single.taskName, 'Updated snapshot');
  });

  test('malformed local records are ignored at startup', () async {
    final storage = FocusSessionStorageService();
    await storage.init();

    final box = Hive.box<dynamic>('focused_focus_sessions');

    await box.put('broken', {
      'id': 'broken',
      'taskName': 'Missing required data',
    });

    await storage.saveSession(
      session(
        id: 'valid',
        startedAt: DateTime(2026, 8, 28, 9),
      ),
    );

    final loaded = storage.loadSessions();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'valid');
  });
}

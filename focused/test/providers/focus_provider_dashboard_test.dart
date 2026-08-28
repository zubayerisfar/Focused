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
      'focused-dashboard-focus-',
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

  FocusSession session({
    required String id,
    required DateTime start,
    required DateTime end,
    required List<FocusInterval> intervals,
  }) {
    return FocusSession(
      id: id,
      taskName: id,
      startedAt: start,
      endedAt: end,
      plannedFocusDuration: const Duration(hours: 2),
      plan: const [
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(hours: 2),
        ),
      ],
      focusIntervals: intervals,
      completedFocusBlocks: 0,
      completedNaturally: false,
    );
  }

  test('focus activity includes every local day crossed by active focus', () async {
    await storage.saveSession(
      session(
        id: 'overnight',
        start: DateTime(2026, 8, 27, 23, 50),
        end: DateTime(2026, 8, 28, 0, 10),
        intervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 27, 23, 50),
            endTime: DateTime(2026, 8, 28, 0, 10),
          ),
        ],
      ),
    );

    final provider = FocusProvider(storageService: storage);
    await provider.loadStoredSessions();

    expect(
      provider.focusActivityDates(),
      containsAll([
        DateTime(2026, 8, 27),
        DateTime(2026, 8, 28),
      ]),
    );
  });

  test('longest focus session is clipped to selected date', () async {
    await storage.saveSession(
      session(
        id: 'overnight',
        start: DateTime(2026, 8, 27, 23, 40),
        end: DateTime(2026, 8, 28, 0, 20),
        intervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 27, 23, 40),
            endTime: DateTime(2026, 8, 28, 0, 20),
          ),
        ],
      ),
    );

    await storage.saveSession(
      session(
        id: 'morning',
        start: DateTime(2026, 8, 28, 9),
        end: DateTime(2026, 8, 28, 9, 35),
        intervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 9),
            endTime: DateTime(2026, 8, 28, 9, 35),
          ),
        ],
      ),
    );

    final provider = FocusProvider(storageService: storage);
    await provider.loadStoredSessions();

    expect(
      provider.longestFocusSessionForDate(DateTime(2026, 8, 28)),
      const Duration(minutes: 35),
    );
    expect(
      provider.longestFocusSessionForDate(DateTime(2026, 8, 27)),
      const Duration(minutes: 20),
    );
  });

  test('overlapping intervals inside one session are not double counted', () async {
    await storage.saveSession(
      session(
        id: 'overlap',
        start: DateTime(2026, 8, 28, 9),
        end: DateTime(2026, 8, 28, 10),
        intervals: [
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 9),
            endTime: DateTime(2026, 8, 28, 9, 30),
          ),
          FocusInterval(
            startTime: DateTime(2026, 8, 28, 9, 20),
            endTime: DateTime(2026, 8, 28, 9, 50),
          ),
        ],
      ),
    );

    final provider = FocusProvider(storageService: storage);
    await provider.loadStoredSessions();

    expect(
      provider.longestFocusSessionForDate(DateTime(2026, 8, 28)),
      const Duration(minutes: 50),
    );
  });
}

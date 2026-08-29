import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:focused/models/focus_analysis_result.dart';
import 'package:focused/models/focus_interruption.dart';
import 'package:focused/services/focus_analysis_storage_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'focused-focus-analysis-',
    );
    Hive.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  FocusAnalysisResult analysis(DateTime start) {
    return FocusAnalysisResult(
      focusStart: start,
      focusEnd: start.add(const Duration(hours: 1)),
      plannedDuration: const Duration(hours: 1),
      actualFocusDuration: const Duration(minutes: 55),
      distractedDuration: const Duration(minutes: 5),
      effectiveFocusDuration: const Duration(minutes: 50),
      interruptionCount: 1,
      completionRate: 91.67,
      attentionRetention: 90.91,
      focusQuality: 83.33,
      topInterrupterApp: 'YouTube',
      distractionByApp: const {
        'YouTube': Duration(minutes: 5),
      },
      interruptions: [
        FocusInterruption(
          appId: 'com.google.android.youtube',
          appName: 'YouTube',
          startTime: start.add(const Duration(minutes: 20)),
          endTime: start.add(const Duration(minutes: 25)),
        ),
      ],
    );
  }

  test('saves and reloads focus analysis by session id', () async {
    final storage = FocusAnalysisStorageService();
    await storage.init();

    final value = analysis(DateTime(2026, 8, 29, 10));
    await storage.saveAnalysis('session-1', value);

    final loaded = storage.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.sessionId, 'session-1');
    expect(loaded.single.analysis.distractedDuration, const Duration(minutes: 5));
    expect(loaded.single.analysis.interruptions.single.appName, 'YouTube');
  });

  test('same session id replaces previous analysis', () async {
    final storage = FocusAnalysisStorageService();
    await storage.init();

    await storage.saveAnalysis(
      'same',
      analysis(DateTime(2026, 8, 29, 10)),
    );
    await storage.saveAnalysis(
      'same',
      analysis(DateTime(2026, 8, 29, 11)),
    );

    final loaded = storage.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.analysis.focusStart.hour, 11);
  });
}

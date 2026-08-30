import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_guard_event.dart';
import 'package:focused/models/focus_guard_status.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/services/focus_guard_service.dart';

void main() {
  test('focus lifecycle mirrors start, pause, resume and stop to Focus Guard', () async {
    var now = DateTime(2026, 8, 30, 20);
    final guard = _RecordingFocusGuard();
    final provider = FocusProvider(
      focusGuardController: guard,
      now: () => now,
    );

    provider.startSession(
      taskId: 'task-1',
      taskName: 'Research',
      totalFocusMinutes: 30,
      focusBlockMinutes: 30,
      breakMinutes: 5,
    );
    await _flushAsyncWork();

    expect(guard.starts, hasLength(1));
    expect(guard.starts.single.taskName, 'Research');
    expect(guard.starts.single.warningThresholdSeconds, 30);
    expect(guard.starts.single.plan, hasLength(1));
    expect(provider.activeSessionId, isNotNull);

    now = DateTime(2026, 8, 30, 20, 10);
    provider.pauseSession();
    await _flushAsyncWork();

    expect(guard.pauseCount, 1);
    expect(guard.lastRemainingSeconds, 20 * 60);

    now = DateTime(2026, 8, 30, 20, 12);
    provider.resumeSession();
    await _flushAsyncWork();

    expect(guard.resumeCount, 1);
    expect(guard.lastRemainingSeconds, 20 * 60);

    now = DateTime(2026, 8, 30, 20, 15);
    provider.endSession();
    await _flushAsyncWork();

    expect(guard.stopCount, 1);
    expect(provider.isRunning, isFalse);
    expect(provider.lastSession!.id, isNotEmpty);
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _GuardStart {
  final String taskName;
  final List<FocusBlock> plan;
  final int warningThresholdSeconds;

  const _GuardStart({
    required this.taskName,
    required this.plan,
    required this.warningThresholdSeconds,
  });
}

class _RecordingFocusGuard implements FocusGuardController {
  final List<_GuardStart> starts = [];
  int pauseCount = 0;
  int resumeCount = 0;
  int syncCount = 0;
  int stopCount = 0;
  int lastRemainingSeconds = 0;

  @override
  Future<void> startFocusGuard({
    required String sessionId,
    required String taskName,
    required List<FocusBlock> plan,
    required int currentBlockIndex,
    required int remainingSeconds,
    String originDevice = 'android',
    int warningThresholdSeconds = 30,
  }) async {
    starts.add(
      _GuardStart(
        taskName: taskName,
        plan: plan,
        warningThresholdSeconds: warningThresholdSeconds,
      ),
    );
    lastRemainingSeconds = remainingSeconds;
  }

  @override
  Future<void> pauseFocusGuard({
    required int currentBlockIndex,
    required int remainingSeconds,
  }) async {
    pauseCount++;
    lastRemainingSeconds = remainingSeconds;
  }

  @override
  Future<void> resumeFocusGuard({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {
    resumeCount++;
    lastRemainingSeconds = remainingSeconds;
  }

  @override
  Future<void> syncFocusGuardPhase({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {
    syncCount++;
    lastRemainingSeconds = remainingSeconds;
  }

  @override
  Future<void> stopFocusGuard() async {
    stopCount++;
  }

  @override
  Future<void> updateFocusGuardAllowedPackages(Set<String> packageNames) async {}

  @override
  Future<void> cacheFocusGuardAllowedPackages(Set<String> packageNames) async {}

  @override
  Future<List<FocusGuardEvent>> getFocusGuardEvents() async => const [];

  @override
  Future<void> clearFocusGuardEvents() async {}

  @override
  Future<FocusGuardStatus> getFocusGuardStatus() async {
    return const FocusGuardStatus(
      isSupported: true,
      serviceRunning: true,
      usageAccessGranted: true,
      notificationsEnabled: true,
      phase: FocusGuardPhase.focus,
      remainingSeconds: 1200,
      warningThresholdSeconds: 30,
    );
  }
}

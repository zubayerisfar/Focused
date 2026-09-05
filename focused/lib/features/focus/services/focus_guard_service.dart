import '../models/focus_block.dart';
import '../models/focus_guard_event.dart';
import '../models/focus_guard_status.dart';

abstract class FocusGuardController {
  Future<void> startFocusGuard({
    required String sessionId,
    required String taskName,
    required List<FocusBlock> plan,
    required int currentBlockIndex,
    required int remainingSeconds,
    String originDevice = 'android',
    int warningThresholdSeconds = 30,
  });

  Future<void> pauseFocusGuard({
    required int currentBlockIndex,
    required int remainingSeconds,
  });

  Future<void> resumeFocusGuard({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  });

  Future<void> syncFocusGuardPhase({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  });

  Future<void> updateFocusGuardAllowedPackages(Set<String> packageNames);

  Future<void> cacheFocusGuardAllowedPackages(Set<String> packageNames);

  Future<void> stopFocusGuard();

  Future<List<FocusGuardEvent>> getFocusGuardEvents();

  Future<void> clearFocusGuardEvents();

  Future<FocusGuardStatus> getFocusGuardStatus();
}

class NoopFocusGuardController implements FocusGuardController {
  const NoopFocusGuardController();

  @override
  Future<void> startFocusGuard({
    required String sessionId,
    required String taskName,
    required List<FocusBlock> plan,
    required int currentBlockIndex,
    required int remainingSeconds,
    String originDevice = 'android',
    int warningThresholdSeconds = 30,
  }) async {}

  @override
  Future<void> pauseFocusGuard({
    required int currentBlockIndex,
    required int remainingSeconds,
  }) async {}

  @override
  Future<void> resumeFocusGuard({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {}

  @override
  Future<void> syncFocusGuardPhase({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {}

  @override
  Future<void> updateFocusGuardAllowedPackages(Set<String> packageNames) async {}

  @override
  Future<void> cacheFocusGuardAllowedPackages(Set<String> packageNames) async {}

  @override
  Future<void> stopFocusGuard() async {}

  @override
  Future<List<FocusGuardEvent>> getFocusGuardEvents() async => const [];

  @override
  Future<void> clearFocusGuardEvents() async {}

  @override
  Future<FocusGuardStatus> getFocusGuardStatus() async =>
      const FocusGuardStatus.unsupported();
}

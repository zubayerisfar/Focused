import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/focus/models/focus_block.dart';
import 'package:focused/features/focus/models/focus_guard_event.dart';
import 'package:focused/features/focus/models/focus_guard_status.dart';
import 'package:focused/features/tasks/models/task.dart';
import 'package:focused/features/focus/providers/focus_provider.dart';
import 'package:focused/features/focus/services/focus_guard_service.dart';

class MockFocusGuardController implements FocusGuardController {
  int? lastWarningThresholdSeconds;
  String? lastSessionId;
  String? lastTaskName;

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
    lastSessionId = sessionId;
    lastTaskName = taskName;
    lastWarningThresholdSeconds = warningThresholdSeconds;
  }

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
  Future<void> updateFocusGuardAllowedPackages(
    Set<String> packageNames,
  ) async {}

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

void main() {
  test('passes custom guardWarningSeconds to native Focus Guard', () async {
    final mockGuard = MockFocusGuardController();
    final focusProvider = FocusProvider(focusGuardController: mockGuard);

    focusProvider.startSession(
      taskId: 'task-1',
      taskName: 'Coding Session',
      totalFocusMinutes: 50,
      focusBlockMinutes: 50,
      breakMinutes: 10,
      guardWarningSeconds: 15,
    );

    expect(focusProvider.guardWarningSeconds, 15);
    // Allow unawaited async guard action to run
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(mockGuard.lastWarningThresholdSeconds, 15);
    expect(mockGuard.lastTaskName, 'Coding Session');

    focusProvider.endSession();
  });

  test('Task model preserves custom guardWarningSeconds', () {
    final task = Task(
      id: 't1',
      title: 'Study Physics',
      priority: TaskPriority.important,
      guardWarningSeconds: 45,
      createdAt: DateTime.now(),
    );

    expect(task.guardWarningSeconds, 45);

    final map = task.toMap();
    expect(map['guardWarningSeconds'], 45);

    final parsed = Task.fromMap(map);
    expect(parsed.guardWarningSeconds, 45);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_category.dart';
import 'package:focused/models/focus_block.dart';
import 'package:focused/models/focus_guard_event.dart';
import 'package:focused/models/focus_guard_status.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/services/focus_guard_service.dart';

void main() {
  test('productive package classifications are pushed to native Focus Guard', () async {
    final guard = _AllowedPackageGuard();
    final provider = UsageProvider(focusGuardController: guard);

    await provider.setAppCategory(
      'com.android.chrome',
      AppCategory.productive,
    );
    await _flushAsyncWork();

    expect(guard.lastUpdated, contains('com.android.chrome'));

    await provider.setAppCategory(
      'com.android.chrome',
      AppCategory.neutral,
    );
    await _flushAsyncWork();

    expect(guard.lastUpdated, isNot(contains('com.android.chrome')));
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _AllowedPackageGuard implements FocusGuardController {
  Set<String> lastUpdated = {};

  @override
  Future<void> updateFocusGuardAllowedPackages(Set<String> packageNames) async {
    lastUpdated = Set<String>.from(packageNames);
  }

  @override
  Future<void> cacheFocusGuardAllowedPackages(Set<String> packageNames) async {
    lastUpdated = Set<String>.from(packageNames);
  }

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
  Future<void> stopFocusGuard() async {}

  @override
  Future<List<FocusGuardEvent>> getFocusGuardEvents() async => const [];

  @override
  Future<void> clearFocusGuardEvents() async {}

  @override
  Future<FocusGuardStatus> getFocusGuardStatus() async =>
      const FocusGuardStatus.unsupported();
}

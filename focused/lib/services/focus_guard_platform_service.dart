import 'dart:io';

import 'package:flutter/services.dart';

import '../models/focus_block.dart';
import '../models/focus_guard_event.dart';
import '../models/focus_guard_status.dart';
import 'focus_guard_service.dart';

class FocusGuardPlatformService implements FocusGuardController {
  static const MethodChannel _channel = MethodChannel('focused/focus_guard');

  bool get _isSupported => Platform.isAndroid;

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
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('startFocusGuard', {
      'sessionId': sessionId,
      'taskName': taskName,
      'originDevice': originDevice,
      'currentBlockIndex': currentBlockIndex,
      'remainingSeconds': remainingSeconds,
      'warningThresholdSeconds': warningThresholdSeconds,
      'plan': plan
          .map(
            (block) => {
              'type': block.isBreak ? 'break' : 'focus',
              'durationSeconds': block.duration.inSeconds,
            },
          )
          .toList(growable: false),
    });
  }

  @override
  Future<void> pauseFocusGuard({
    required int currentBlockIndex,
    required int remainingSeconds,
  }) async {
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('pauseFocusGuard', {
      'currentBlockIndex': currentBlockIndex,
      'remainingSeconds': remainingSeconds,
    });
  }

  @override
  Future<void> resumeFocusGuard({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('resumeFocusGuard', {
      'currentBlockIndex': currentBlockIndex,
      'phase': isBreak ? 'break' : 'focus',
      'remainingSeconds': remainingSeconds,
    });
  }

  @override
  Future<void> syncFocusGuardPhase({
    required int currentBlockIndex,
    required bool isBreak,
    required int remainingSeconds,
  }) async {
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('syncFocusGuardPhase', {
      'currentBlockIndex': currentBlockIndex,
      'phase': isBreak ? 'break' : 'focus',
      'remainingSeconds': remainingSeconds,
    });
  }

  @override
  Future<void> updateFocusGuardAllowedPackages(Set<String> packageNames) async {
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('updateFocusGuardAllowedPackages', {
      'packageNames': packageNames.toList(growable: false),
    });
  }

  @override
  Future<void> cacheFocusGuardAllowedPackages(Set<String> packageNames) async {
    if (!_isSupported) return;

    await _channel.invokeMethod<void>('cacheFocusGuardAllowedPackages', {
      'packageNames': packageNames.toList(growable: false),
    });
  }

  @override
  Future<void> stopFocusGuard() async {
    if (!_isSupported) return;
    await _channel.invokeMethod<void>('stopFocusGuard');
  }

  @override
  Future<List<FocusGuardEvent>> getFocusGuardEvents() async {
    if (!_isSupported) return const [];

    final raw = await _channel.invokeMethod<List<dynamic>>('getFocusGuardEvents');
    if (raw == null) return const [];

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(FocusGuardEvent.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> clearFocusGuardEvents() async {
    if (!_isSupported) return;
    await _channel.invokeMethod<void>('clearFocusGuardEvents');
  }

  @override
  Future<FocusGuardStatus> getFocusGuardStatus() async {
    if (!_isSupported) {
      return const FocusGuardStatus.unsupported();
    }

    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getFocusGuardSnapshot',
    );

    if (raw == null) {
      return const FocusGuardStatus.unsupported();
    }

    return FocusGuardStatus.fromMap(raw);
  }
}

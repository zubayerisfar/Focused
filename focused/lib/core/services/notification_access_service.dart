import 'dart:io';

import 'package:flutter/services.dart';

import '../../features/settings/models/notification_event.dart';

class NotificationAccessService {
  static const MethodChannel _channel = MethodChannel(
    'focused/notification_events',
  );

  bool get isSupported => Platform.isAndroid;

  Future<bool> hasAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasNotificationAccess') ?? false;
  }

  Future<void> openSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  Future<void> openAppNotificationSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openAppNotificationSettings');
  }

  Future<List<NotificationEvent>> queryEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!isSupported || !end.isAfter(start)) return const [];

    final raw = await _channel.invokeMethod<List<dynamic>>(
          'getNotificationEvents',
          {
            'startMillis': start.millisecondsSinceEpoch,
            'endMillis': end.millisecondsSinceEpoch,
          },
        ) ??
        const <dynamic>[];

    final result = <NotificationEvent>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(NotificationEvent.fromMap(item));
      } catch (_) {
        // Ignore one malformed native record rather than losing the page.
      }
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return List<NotificationEvent>.unmodifiable(result);
  }

  Future<void> pruneBefore(DateTime cutoff) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>(
      'pruneNotificationEvents',
      {'cutoffMillis': cutoff.millisecondsSinceEpoch},
    );
  }
}

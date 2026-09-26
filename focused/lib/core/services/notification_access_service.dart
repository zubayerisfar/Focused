import 'dart:io';

import 'package:flutter/services.dart';

class NotificationAccessService {
  static const MethodChannel _channel = MethodChannel(
    'focused/notification_events',
  );

  bool get isSupported => Platform.isAndroid;

  Future<void> openAppNotificationSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openAppNotificationSettings');
  }
}

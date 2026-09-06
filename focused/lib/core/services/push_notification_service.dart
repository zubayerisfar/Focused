import 'dart:io';
import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling FCM background message: ${message.messageId}');
  PushNotificationService.displayMessageLocally(message);
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _currentUid;

  /// Display a notification locally so custom largeIcons and channel sounds are preserved
  static Future<void> displayMessageLocally(RemoteMessage message) async {
    try {
      final data = message.data;
      final title = data['title'] ?? message.notification?.title;
      final body = data['body'] ?? message.notification?.body;
      if (title == null || body == null) return;

      final channelId = data['channelId'] ?? 'focused_friend_reminders_v2';
      final largeIconName = data['largeIcon'] ?? 'notif_friends';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Friend & Social Alerts',
        channelDescription:
            'Notifications for friend nudges, streaks, and squad updates.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        largeIcon: DrawableResourceAndroidBitmap(largeIconName),
        color: const Color(0xFF4E25AA),
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        playSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          sound: 'notification_sound.mp3',
          presentSound: true,
        ),
      );

      final notifId =
          (message.messageId ?? DateTime.now().toIso8601String()).hashCode
              .abs() %
          100000;
      await _localNotifications.show(notifId, title, body, notifDetails);
    } catch (e) {
      debugPrint('Error displaying FCM notification locally: $e');
    }
  }

  /// Call during app bootstrap
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Listen for token updates from Google Play Services
      _messaging.onTokenRefresh.listen((newToken) {
        if (_currentUid != null && _currentUid!.isNotEmpty) {
          _updateUserToken(_currentUid!, newToken);
        }
      });
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }
  }

  /// Request runtime permission and synchronize token for authenticated user
  static Future<void> syncUserToken(String uid) async {
    _currentUid = uid;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _updateUserToken(uid, token);
        }
      }
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  /// Remove token when user logs out so this device stops receiving their alerts
  static Future<void> clearUserToken(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    } finally {
      if (_currentUid == uid) {
        _currentUid = null;
      }
    }
  }

  static Future<void> _updateUserToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmPlatform': Platform.isAndroid
            ? 'android'
            : (Platform.isIOS ? 'ios' : 'other'),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Synced FCM token for user $uid');
    } catch (e) {
      debugPrint('Failed to save FCM token to Firestore: $e');
    }
  }
}

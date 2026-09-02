import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_limit.dart';
import '../services/app_limit_storage_service.dart';

class AppLimitProvider extends ChangeNotifier {
  AppLimitProvider({
    required AppLimitStore storageService,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _storageService = storageService,
       _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final AppLimitStore _storageService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  final Map<String, AppLimit> _limits = {};

  List<AppLimit> get limits => List.unmodifiable(_limits.values);

  AppLimit? getLimit(String packageId) => _limits[packageId];

  Future<void> loadStoredLimits() async {
    final stored = _storageService.loadLimits();
    _limits
      ..clear()
      ..addEntries(stored.map((limit) => MapEntry(limit.packageId, limit)));
    notifyListeners();
  }

  Future<void> setLimit({
    required String packageId,
    required String appName,
    required int dailyLimitMinutes,
    bool isEnabled = true,
  }) async {
    final existing = _limits[packageId];
    final updated = AppLimit(
      packageId: packageId,
      appName: appName,
      dailyLimitMinutes: dailyLimitMinutes,
      isEnabled: isEnabled,
      lastWarningDate: existing?.lastWarningDate,
    );

    _limits[packageId] = updated;
    notifyListeners();

    try {
      await _storageService.saveLimit(updated);
    } catch (e) {
      if (existing != null) {
        _limits[packageId] = existing;
      } else {
        _limits.remove(packageId);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleLimit(String packageId) async {
    final existing = _limits[packageId];
    if (existing == null) return;

    final updated = existing.copyWith(isEnabled: !existing.isEnabled);
    _limits[packageId] = updated;
    notifyListeners();

    try {
      await _storageService.saveLimit(updated);
    } catch (_) {
      _limits[packageId] = existing;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeLimit(String packageId) async {
    final existing = _limits[packageId];
    if (existing == null) return;

    _limits.remove(packageId);
    notifyListeners();

    try {
      await _storageService.deleteLimit(packageId);
    } catch (_) {
      _limits[packageId] = existing;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> checkUsageLimits(
    Map<String, Duration> todayUsageByPackage,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entry in _limits.entries) {
      final limit = entry.value;
      if (!limit.isEnabled) continue;

      final used = todayUsageByPackage[limit.packageId] ?? Duration.zero;
      final limitDuration = Duration(minutes: limit.dailyLimitMinutes);

      if (used >= limitDuration) {
        final lastWarning = limit.lastWarningDate;
        final alreadyWarnedToday =
            lastWarning != null &&
            lastWarning.year == today.year &&
            lastWarning.month == today.month &&
            lastWarning.day == today.day;

        if (!alreadyWarnedToday) {
          await _sendOverUsageNotification(
            limit: limit,
            usedMinutes: used.inMinutes,
          );

          final updated = limit.copyWith(lastWarningDate: now);
          _limits[limit.packageId] = updated;
          await _storageService.saveLimit(updated);
          notifyListeners();
        }
      }
    }
  }

  Future<void> _sendOverUsageNotification({
    required AppLimit limit,
    required int usedMinutes,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'focused_app_limits',
      'App Daily Limits',
      channelDescription: 'Alerts when daily app usage limit is reached',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id = limit.packageId.hashCode & 0x7FFFFFFF;
    final usedStr = _formatMinutes(usedMinutes);
    final limitStr = _formatMinutes(limit.dailyLimitMinutes);

    try {
      await _notificationsPlugin.show(
        id,
        '⚠️ Daily Limit Reached: ${limit.appName}',
        'You have used ${limit.appName} for $usedStr today (Limit: $limitStr). Time for a break!',
        details,
      );
    } catch (e) {
      debugPrint('Could not post app limit notification: $e');
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

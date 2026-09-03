import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/task_notification_service.dart';
import '../services/user_profile_storage_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({
    UserProfileStore? storageService,
    TaskNotificationService? notificationService,
  }) : _storageService = storageService,
       _notificationService = notificationService;

  final UserProfileStore? _storageService;
  final TaskNotificationService? _notificationService;

  UserProfile _profile = const UserProfile(
    displayName: 'Focused User',
    email: '',
  );

  UserProfile get profile => _profile;

  Future<void> loadStoredProfile() async {
    final stored = _storageService?.loadProfile();
    if (stored != null) {
      _profile = stored;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String email,
    String? username,
    String? nationality,
    DateTime? birthday,
    bool clearBirthday = false,
  }) async {
    final next = UserProfile(
      displayName: displayName.trim().isEmpty
          ? 'Focused User'
          : displayName.trim(),
      email: email.trim(),
      username: username != null ? username.trim().replaceAll('@', '') : _profile.username,
      joinedYear: _profile.joinedYear,
      nationality: nationality ?? _profile.nationality,
      birthday: clearBirthday ? null : (birthday ?? _profile.birthday),
    );

    final previous = _profile;
    _profile = next;
    notifyListeners();

    try {
      await _storageService?.saveProfile(next);

      final notifications = _notificationService;
      if (notifications != null) {
        if (next.birthday == null) {
          await notifications.cancelBirthdayNotification();
        } else {
          await notifications.scheduleBirthdayNotification(
            birthday: next.birthday!,
            displayName: next.displayName,
          );
        }
      }
    } catch (_) {
      _profile = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resetProfile() async {
    _profile = const UserProfile(displayName: 'Focused User', email: '');
    notifyListeners();
    try {
      await _notificationService?.cancelBirthdayNotification();
    } catch (_) {}
  }
}

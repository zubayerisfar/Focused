import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../../tasks/services/task_notification_service.dart';
import '../services/user_profile_storage_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({
    UserProfileStore? storageService,
    TaskNotificationService? notificationService,
    FirebaseFirestore? firestore,
  }) : _storageService = storageService,
       _notificationService = notificationService,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final UserProfileStore? _storageService;
  final TaskNotificationService? _notificationService;
  final FirebaseFirestore _firestore;

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

  /// Synchronizes user profile with Firestore `users/{uid}` and `users/{uid}/private/profile`
  Future<void> syncFromFirestore(String uid) async {
    if (uid.isEmpty) return;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;
      final data = userDoc.data() ?? {};
      final firestoreUsername = data['username'] as String?;
      final firestoreDisplayName = data['displayName'] as String?;

      String? email;
      String? nationality;
      DateTime? birthday;

      try {
        final privateDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('private')
            .doc('profile')
            .get();
        if (privateDoc.exists) {
          final pData = privateDoc.data() ?? {};
          email = pData['email'] as String?;
          nationality = pData['nationality'] as String?;
          final bTs = pData['birthday'] as Timestamp?;
          birthday = bTs?.toDate();
        }
      } catch (e) {
        debugPrint('Could not load private profile: $e');
      }

      await updateProfile(
        displayName:
            (firestoreDisplayName != null &&
                firestoreDisplayName.isNotEmpty &&
                firestoreDisplayName != 'Focused User')
            ? firestoreDisplayName
            : (_profile.displayName.isNotEmpty &&
                      _profile.displayName != 'Focused User'
                  ? _profile.displayName
                  : (firestoreDisplayName ?? _profile.displayName)),
        email: (email != null && email.isNotEmpty) ? email : _profile.email,
        username:
            (firestoreUsername != null &&
                firestoreUsername.isNotEmpty &&
                firestoreUsername.toLowerCase() != 'focuseduser' &&
                firestoreUsername.toLowerCase() != 'focused_user')
            ? firestoreUsername
            : _profile.username,
        nationality: nationality ?? _profile.nationality,
        birthday: birthday ?? _profile.birthday,
      );
    } catch (e) {
      debugPrint('Error syncing profile from Firestore: $e');
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
    final cleanProvidedUsername = username?.trim().replaceAll('@', '');
    final resolvedUsername =
        (cleanProvidedUsername != null &&
            cleanProvidedUsername.isNotEmpty &&
            cleanProvidedUsername.toLowerCase() != 'focuseduser' &&
            cleanProvidedUsername.toLowerCase() != 'focused_user')
        ? cleanProvidedUsername
        : (_profile.username.trim().isNotEmpty &&
              _profile.username.trim().toLowerCase() != 'focuseduser' &&
              _profile.username.trim().toLowerCase() != 'focused_user')
        ? _profile.username.trim()
        : UserProfile.defaultUsernameFromEmail(email);

    final next = UserProfile(
      displayName: displayName.trim().isEmpty
          ? 'Focused User'
          : displayName.trim(),
      email: email.trim(),
      username: resolvedUsername,
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
      await _storageService?.saveProfile(_profile);
      await _notificationService?.cancelBirthdayNotification();
    } catch (_) {}
  }
}

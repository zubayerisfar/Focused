import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_storage_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileProvider({UserProfileStore? storageService})
      : _storageService = storageService;

  final UserProfileStore? _storageService;

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
  }) async {
    final next = UserProfile(
      displayName: displayName.trim().isEmpty ? 'Focused User' : displayName.trim(),
      email: email.trim(),
    );
    final previous = _profile;
    _profile = next;
    notifyListeners();

    try {
      await _storageService?.saveProfile(next);
    } catch (_) {
      _profile = previous;
      notifyListeners();
      rethrow;
    }
  }
}

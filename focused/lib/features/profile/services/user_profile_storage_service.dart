import 'package:hive_ce/hive_ce.dart';

import '../models/user_profile.dart';

abstract class UserProfileStore {
  UserProfile? loadProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> clearProfile();
}

class UserProfileStorageService implements UserProfileStore {
  static const _boxName = 'focused_profile';
  static const _profileKey = 'profile';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _profileBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'UserProfileStorageService.init() must be called first.',
      );
    }
    return box;
  }

  @override
  UserProfile? loadProfile() {
    final raw = _profileBox.get(_profileKey);
    if (raw is! Map) return null;
    try {
      return UserProfile.fromMap(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _profileBox.put(_profileKey, profile.toMap());
  }

  @override
  Future<void> clearProfile() {
    return _profileBox.delete(_profileKey);
  }
}

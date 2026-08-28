import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/user_profile.dart';
import 'package:focused/providers/user_profile_provider.dart';
import 'package:focused/services/user_profile_storage_service.dart';

class _MemoryProfileStore implements UserProfileStore {
  UserProfile? value;

  @override
  UserProfile? loadProfile() => value;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    value = profile;
  }
}

void main() {
  test('local personal info persists and reloads', () async {
    final store = _MemoryProfileStore();
    final first = UserProfileProvider(storageService: store);

    await first.updateProfile(
      displayName: 'Mahadi Hasan',
      email: 'mahadi@example.com',
    );

    final second = UserProfileProvider(storageService: store);
    await second.loadStoredProfile();

    expect(second.profile.displayName, 'Mahadi Hasan');
    expect(second.profile.email, 'mahadi@example.com');
  });
}

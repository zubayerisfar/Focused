import 'package:flutter_test/flutter_test.dart';
import 'package:focused/features/profile/models/user_profile.dart';

void main() {
  group('UserProfile.defaultUsernameFromEmail', () {
    test('extracts first part before @ and removes dots', () {
      expect(
        UserProfile.defaultUsernameFromEmail('john.doe@gmail.com'),
        'johndoe',
      );
      expect(
        UserProfile.defaultUsernameFromEmail('first.middle.last@domain.com'),
        'firstmiddlelast',
      );
      expect(
        UserProfile.defaultUsernameFromEmail('z.ishfar.zeem@outlook.com'),
        'zishfarzeem',
      );
    });

    test('handles emails without dots', () {
      expect(
        UserProfile.defaultUsernameFromEmail('simpleuser@gmail.com'),
        'simpleuser',
      );
    });

    test(
      'removes special characters and keeps underscores and alphanumeric',
      () {
        expect(
          UserProfile.defaultUsernameFromEmail('alex.smith_99+tag@gmail.com'),
          'alexsmith_99tag',
        );
      },
    );

    test('returns fallback for empty or invalid email', () {
      expect(
        UserProfile.defaultUsernameFromEmail('', fallback: 'user'),
        'user',
      );
      expect(
        UserProfile.defaultUsernameFromEmail(null, fallback: 'custom_fallback'),
        'custom_fallback',
      );
      expect(
        UserProfile.defaultUsernameFromEmail('invalidemail', fallback: 'user'),
        'user',
      );
    });

    test(
      'UserProfile.handle uses default username without dots when username is empty',
      () {
        const profile = UserProfile(
          displayName: 'John Doe',
          email: 'john.doe@gmail.com',
          username: '',
        );
        expect(profile.handle, '@johndoe');
      },
    );

    test('UserProfile.handle prioritizes custom username when set', () {
      const profile = UserProfile(
        displayName: 'John Doe',
        email: 'john.doe@gmail.com',
        username: 'custom_handle',
      );
      expect(profile.handle, '@custom_handle');
    });

    test(
      'UserProfile.handle ignores focuseduser and uses default username from email',
      () {
        const profile = UserProfile(
          displayName: 'Focused User',
          email: 'ug2202077@cse.pstu.ac.bd',
          username: 'focuseduser',
        );
        expect(profile.handle, '@ug2202077');
      },
    );
  });
}

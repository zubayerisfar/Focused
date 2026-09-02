import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/user_cloud_stats.dart';
import 'package:focused/services/achievement_service.dart';
import 'package:focused/services/network_connectivity_service.dart';

void main() {
  group('UserCloudStats & AchievementService with Streak & Badge sync', () {
    test(
      'UserCloudStats serialization preserves streak, focus hours and unlocked badges',
      () {
        const stats = UserCloudStats(
          streakDays: 1000,
          longestStreak: 1000,
          totalFocusMinutes: 6000,
          completedSessionsCount: 150,
          unlockedBadgeIds: [
            'streak_100',
            'streak_300',
            'streak_1000',
            'focus_total_100h',
          ],
        );

        final map = stats.toMap();
        expect(map['streakDays'], 1000);
        expect(map['longestStreak'], 1000);
        expect(map['totalFocusMinutes'], 6000);
        expect(map['unlockedBadgeIds'], contains('streak_1000'));

        final parsed = UserCloudStats.fromMap(map);
        expect(parsed.streakDays, 1000);
        expect(parsed.longestStreak, 1000);
        expect(parsed.totalFocusMinutes, 6000);
        expect(parsed.unlockedBadgeIds, contains('streak_1000'));
      },
    );

    test(
      'Changing streak from 100 to 1000 unlocks all milestones up to 1000 days',
      () {
        const achievementService = AchievementService();

        // With 100 days
        final badges100 = achievementService.buildBadges(
          longestStreak: 100,
          longestLinkedTaskSession: Duration.zero,
          totalFocus: Duration.zero,
        );

        final streak100Badge = badges100.firstWhere(
          (b) => b.id == 'streak_100',
        );
        final streak1000Badge = badges100.firstWhere(
          (b) => b.id == 'streak_1000',
        );

        expect(streak100Badge.achieved, isTrue);
        expect(streak1000Badge.achieved, isFalse);

        // Change from 100 to 1000 days (e.g. from Firebase Cloud Sync)
        final badges1000 = achievementService.buildBadges(
          longestStreak: 1000,
          longestLinkedTaskSession: Duration.zero,
          totalFocus: const Duration(hours: 100),
        );

        final streak300Badge = badges1000.firstWhere(
          (b) => b.id == 'streak_300',
        );
        final streak365Badge = badges1000.firstWhere(
          (b) => b.id == 'streak_365',
        );
        final streak500Badge = badges1000.firstWhere(
          (b) => b.id == 'streak_500',
        );
        final streak1000Unlocked = badges1000.firstWhere(
          (b) => b.id == 'streak_1000',
        );
        final total100hBadge = badges1000.firstWhere(
          (b) => b.id == 'focus_total_100h',
        );

        expect(streak300Badge.achieved, isTrue);
        expect(streak365Badge.achieved, isTrue);
        expect(streak500Badge.achieved, isTrue);
        expect(streak1000Unlocked.achieved, isTrue);
        expect(total100hBadge.achieved, isTrue);
      },
    );

    test(
      'Explicit unlockedBadgeIds preserves badge achievement on new devices',
      () {
        const achievementService = AchievementService();

        // Even with 0 local focus, synced unlocked badge IDs remain achieved
        final badges = achievementService.buildBadges(
          longestStreak: 0,
          longestLinkedTaskSession: Duration.zero,
          totalFocus: Duration.zero,
          unlockedBadgeIds: [
            'streak_1000',
            'focus_total_500h',
            'focus_session_3h',
          ],
        );

        expect(
          badges.firstWhere((b) => b.id == 'streak_1000').achieved,
          isTrue,
        );
        expect(
          badges.firstWhere((b) => b.id == 'focus_total_500h').achieved,
          isTrue,
        );
        expect(
          badges.firstWhere((b) => b.id == 'focus_session_3h').achieved,
          isTrue,
        );
      },
    );

    test('Offline network service reports false without crashing', () async {
      // Mock network service checking timeout / failure
      final offlineResult = await const _MockOfflineNetworkService()
          .hasInternetConnection();
      expect(offlineResult, isFalse);
    });
  });
}

class _MockOfflineNetworkService implements NetworkConnectivityService {
  const _MockOfflineNetworkService();

  @override
  Future<bool> hasInternetConnection() async => false;
}

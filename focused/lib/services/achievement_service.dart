import '../models/achievement_badge.dart';

class AchievementService {
  const AchievementService();

  List<AchievementBadge> buildBadges({
    required int longestStreak,
    required Duration longestLinkedTaskSession,
    required Duration totalFocus,
  }) {
    final badges = <AchievementBadge>[
      ..._streakBadges(longestStreak),
      ..._sessionBadges(longestLinkedTaskSession),
      ..._totalFocusBadges(totalFocus),
    ];

    return List<AchievementBadge>.unmodifiable(badges);
  }

  List<AchievementBadge> _streakBadges(int longestStreak) {
    const milestones = <int>[7, 30, 60, 100, 120, 180, 300];

    return milestones
        .map(
          (days) => AchievementBadge(
            id: 'streak_$days',
            title: '$days day streak',
            description: 'Reach a $days-day productivity streak.',
            assetPath: 'assets/badges/streak_$days.png',
            category: AchievementBadgeCategory.streak,
            achieved: longestStreak >= days,
            progress: longestStreak.toDouble(),
            target: days.toDouble(),
          ),
        )
        .toList(growable: false);
  }

  List<AchievementBadge> _sessionBadges(Duration longestLinkedTaskSession) {
    final hours = longestLinkedTaskSession.inSeconds / 3600.0;

    return [
      AchievementBadge(
        id: 'focus_session_1h',
        title: 'One-hour task',
        description:
            'Finish a linked task focus session with 1 hour of real focus.',
        assetPath: 'assets/badges/focus_session_1h.png',
        category: AchievementBadgeCategory.focusSession,
        achieved: hours >= 1,
        progress: hours,
        target: 1,
      ),
      AchievementBadge(
        id: 'focus_session_3h',
        title: 'Three-hour task',
        description:
            'Finish a linked task focus session with 3 hours of real focus.',
        assetPath: 'assets/badges/focus_session_3h.png',
        category: AchievementBadgeCategory.focusSession,
        achieved: hours >= 3,
        progress: hours,
        target: 3,
      ),
    ];
  }

  List<AchievementBadge> _totalFocusBadges(Duration totalFocus) {
    final hours = totalFocus.inSeconds / 3600.0;

    const milestones = <int>[20, 50, 60, 100, 200, 300, 500, 1000];

    return milestones
        .map(
          (targetHours) => AchievementBadge(
            id: 'focus_total_${targetHours}h',
            title: '$targetHours focus hours',
            description: 'Accumulate $targetHours hours of real focused work.',
            assetPath: _totalFocusAssetPath(targetHours),
            category: AchievementBadgeCategory.totalFocus,
            achieved: hours >= targetHours,
            progress: hours,
            target: targetHours.toDouble(),
          ),
        )
        .toList(growable: false);
  }

  String _totalFocusAssetPath(int targetHours) {
    // The first four badges keep the original Focused filenames.
    // The new high-hour badge artwork uses the filenames the user added.
    switch (targetHours) {
      case 20:
      case 50:
      case 60:
      case 100:
        return 'assets/badges/focus_total_${targetHours}h.png';
      case 200:
      case 300:
      case 500:
      case 1000:
        return 'assets/badges/focus_session_${targetHours}h.png';
      default:
        throw ArgumentError.value(
          targetHours,
          'targetHours',
          'Unsupported total-focus badge milestone.',
        );
    }
  }
}

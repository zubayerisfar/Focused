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

  List<AchievementBadge> _sessionBadges(
    Duration longestLinkedTaskSession,
  ) {
    final hours = longestLinkedTaskSession.inSeconds / 3600.0;

    return [
      AchievementBadge(
        id: 'focus_session_1h',
        title: 'One-hour task',
        description: 'Finish a linked task focus session with 1 hour of real focus.',
        assetPath: 'assets/badges/focus_session_1h.png',
        category: AchievementBadgeCategory.focusSession,
        achieved: hours >= 1,
        progress: hours,
        target: 1,
      ),
      AchievementBadge(
        id: 'focus_session_3h',
        title: 'Three-hour task',
        description: 'Finish a linked task focus session with 3 hours of real focus.',
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
            assetPath: 'assets/badges/focus_total_${targetHours}h.png',
            category: AchievementBadgeCategory.totalFocus,
            achieved: hours >= targetHours,
            progress: hours,
            target: targetHours.toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

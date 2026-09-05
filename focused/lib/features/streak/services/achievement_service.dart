import 'dart:math' as math;

import '../models/achievement_badge.dart';

class AchievementService {
  const AchievementService();

  List<AchievementBadge> buildBadges({
    required int longestStreak,
    required Duration longestLinkedTaskSession,
    required Duration totalFocus,
    Iterable<String> unlockedBadgeIds = const <String>[],
  }) {
    final unlockedSet = unlockedBadgeIds.toSet();

    final badges = <AchievementBadge>[
      ..._streakBadges(longestStreak, unlockedSet),
      ..._sessionBadges(longestLinkedTaskSession, unlockedSet),
      ..._totalFocusBadges(totalFocus, unlockedSet),
    ];

    return List<AchievementBadge>.unmodifiable(badges);
  }

  List<AchievementBadge> _streakBadges(
    int longestStreak,
    Set<String> unlockedSet,
  ) {
    const milestones = <int>[7, 30, 60, 100, 120, 180, 300, 365, 500, 1000];

    return milestones
        .map(
          (days) {
            final id = 'streak_$days';
            final isAchieved = longestStreak >= days || unlockedSet.contains(id);
            final currentProgress = isAchieved
                ? math.max(longestStreak.toDouble(), days.toDouble())
                : longestStreak.toDouble();

            return AchievementBadge(
              id: id,
              title: '$days day streak',
              description: 'Reach a $days-day productivity streak.',
              assetPath: 'assets/badges/streak_$days.png',
              category: AchievementBadgeCategory.streak,
              achieved: isAchieved,
              progress: currentProgress,
              target: days.toDouble(),
            );
          },
        )
        .toList(growable: false);
  }

  List<AchievementBadge> _sessionBadges(
    Duration longestLinkedTaskSession,
    Set<String> unlockedSet,
  ) {
    final hours = longestLinkedTaskSession.inSeconds / 3600.0;

    return [
      AchievementBadge(
        id: 'focus_session_1h',
        title: 'One-hour task',
        description:
            'Finish a linked task focus session with 1 hour of real focus.',
        assetPath: 'assets/badges/focus_session_1h.png',
        category: AchievementBadgeCategory.focusSession,
        achieved: hours >= 1 || unlockedSet.contains('focus_session_1h'),
        progress: (hours >= 1 || unlockedSet.contains('focus_session_1h'))
            ? math.max(hours, 1.0)
            : hours,
        target: 1,
      ),
      AchievementBadge(
        id: 'focus_session_3h',
        title: 'Three-hour task',
        description:
            'Finish a linked task focus session with 3 hours of real focus.',
        assetPath: 'assets/badges/focus_session_3h.png',
        category: AchievementBadgeCategory.focusSession,
        achieved: hours >= 3 || unlockedSet.contains('focus_session_3h'),
        progress: (hours >= 3 || unlockedSet.contains('focus_session_3h'))
            ? math.max(hours, 3.0)
            : hours,
        target: 3,
      ),
    ];
  }

  List<AchievementBadge> _totalFocusBadges(
    Duration totalFocus,
    Set<String> unlockedSet,
  ) {
    final hours = totalFocus.inSeconds / 3600.0;
    const milestones = <int>[20, 50, 60, 100, 200, 300, 500, 1000];

    return milestones
        .map(
          (targetHours) {
            final id = 'focus_total_${targetHours}h';
            final isAchieved = hours >= targetHours || unlockedSet.contains(id);
            final currentProgress = isAchieved
                ? math.max(hours, targetHours.toDouble())
                : hours;

            return AchievementBadge(
              id: id,
              title: '$targetHours focus hours',
              description: 'Accumulate $targetHours hours of real focused work.',
              assetPath: 'assets/badges/focus_total_${targetHours}h.png',
              category: AchievementBadgeCategory.totalFocus,
              achieved: isAchieved,
              progress: currentProgress,
              target: targetHours.toDouble(),
            );
          },
        )
        .toList(growable: false);
  }
}

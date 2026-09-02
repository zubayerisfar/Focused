import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_badge.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/productivity_streak_service.dart';
import '../../widgets/achievement_badge_art.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const _streakService = ProductivityStreakService();
  static const _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final habits = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();

    final activityDates = <DateTime>{
      ...tasks.completionActivityDates(),
      ...focus.focusActivityDates(),
      ...habits.habitCompletionDates(),
    };

    final localLongest = _streakService.calculateLongestStreak(
      activityDates: activityDates,
    );
    final effectiveLongestStreak = math.max(
      math.max(localLongest, userStats.syncedLongestStreak),
      userStats.syncedStreakDays,
    );

    final localTotalFocus = focus.totalStoredFocusDuration;
    final effectiveTotalFocus = localTotalFocus > userStats.syncedFocusDuration
        ? localTotalFocus
        : userStats.syncedFocusDuration;

    final badges = _achievementService.buildBadges(
      longestStreak: effectiveLongestStreak,
      longestLinkedTaskSession: focus.longestLinkedTaskSessionFocusDuration,
      totalFocus: effectiveTotalFocus,
      unlockedBadgeIds: userStats.unlockedBadgeIds,
    );
    final earned = badges.where((badge) => badge.achieved).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 42)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$earned / ${badges.length} unlocked',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your badges are calculated from real Focused history.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _BadgeSection(
            title: 'Streak badges',
            badges: badges
                .where(
                  (badge) => badge.category == AchievementBadgeCategory.streak,
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
          _BadgeSection(
            title: 'Task-session badges',
            badges: badges
                .where(
                  (badge) =>
                      badge.category == AchievementBadgeCategory.focusSession,
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
          _BadgeSection(
            title: 'Total focus badges',
            badges: badges
                .where(
                  (badge) =>
                      badge.category == AchievementBadgeCategory.totalFocus,
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.title, required this.badges});

  final String title;
  final List<AchievementBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) => _BadgeCard(badge: badges[index]),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: badge.achieved
              ? scheme.primary.withOpacity(0.34)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          AchievementBadgeArt(badge: badge, size: 86),
          const SizedBox(height: 10),
          Text(
            badge.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            badge.achieved ? 'Unlocked' : badge.description,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (!badge.achieved)
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: badge.progressRatio,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}

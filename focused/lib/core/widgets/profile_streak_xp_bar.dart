import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/account_provider.dart';
import '../../features/focus/providers/focus_provider.dart';
import '../../features/habits/providers/habit_provider.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../../features/streak/providers/user_stats_provider.dart';
import '../../features/streak/services/productivity_streak_service.dart';

/// Reusable top-bar component that displays XP chip, Streak chip, and profile avatar
class ProfileStreakXpBar extends StatelessWidget {
  final bool showProfile;
  final double avatarRadius;

  const ProfileStreakXpBar({
    super.key,
    this.showProfile = true,
    this.avatarRadius = 19,
  });

  static const _streakService = ProductivityStreakService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();
    final account = context.watch<AccountProvider>();

    final now = DateTime.now();
    final activityDates = <DateTime>{
      ...taskProvider.completionActivityDates(),
      ...focusProvider.focusActivityDates(),
      ...habitProvider.habitCompletionDates(),
    };
    final localStreak = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
    );
    final streak = math.max(localStreak, userStats.syncedStreakDays);
    final xpPoints = userStats.xpPoints;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    final chipPadding = EdgeInsets.symmetric(horizontal: compact ? 8 : 12);
    final chipGap = compact ? 5.0 : 8.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // XP chip
        InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => context.push('/xp'),
          child: Container(
            height: 36,
            padding: chipPadding,
            decoration: BoxDecoration(
              color: const Color(
                0xFF1CB0F6,
              ).withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFF1CB0F6).withValues(alpha: 0.32),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFF1CB0F6),
                ),
                const SizedBox(width: 4),
                Text(
                  '$xpPoints',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1CB0F6),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: chipGap),

        // Streak chip
        InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => context.push('/streak'),
          child: Container(
            height: 36,
            padding: chipPadding,
            decoration: BoxDecoration(
              color: const Color(
                0xFFFF9600,
              ).withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0xFFFF9600).withValues(alpha: 0.32),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 15, height: 1.0)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFF9600),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (showProfile) ...[
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(avatarRadius + 4),
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: account.photoUrl == null
                  ? null
                  : NetworkImage(account.photoUrl!),
              child: account.photoUrl == null
                  ? Text(
                      account.displayName.trim().isEmpty
                          ? '?'
                          : account.displayName.trim()[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: avatarRadius * 0.75,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/account_provider.dart';
import '../../features/focus/providers/focus_provider.dart';
import '../../features/habits/providers/habit_provider.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../../features/streak/providers/user_stats_provider.dart';
import '../../features/streak/services/productivity_streak_service.dart';

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}

/// Reusable top-bar component that displays Gem chip, Streak chip, and profile avatar
class ProfileStreakXpBar extends StatelessWidget {
  final bool showProfile;
  final double avatarRadius;

  const ProfileStreakXpBar({
    super.key,
    this.showProfile = true,
    this.avatarRadius = 20,
  });

  static const _streakService = ProductivityStreakService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

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
    final streakDetails = _streakService.evaluateStreakDetails(
      now: now,
      activityDates: activityDates,
      restoredDates: userStats.parsedRestoredStreakDates,
      debugForceDanger: userStats.debugSimulateStreakInDanger,
    );
    final isInDanger = streakDetails.isInDanger;
    final streak = math.max(streakDetails.currentStreak, userStats.syncedStreakDays);
    final gems = userStats.gems;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 380;
    final chipPadding = EdgeInsets.symmetric(horizontal: compact ? 8 : 12);
    final chipGap = compact ? 5.0 : 8.0;

    final streakColor = isInDanger ? const Color(0xFFEF4444) : const Color(0xFFFF9600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Gem chip
        InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => context.push('/xp'),
          child: Container(
            height: 38,
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
                SvgPicture.asset(
                  'assets/icon/gem.svg',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  '$gems',
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
            height: 38,
            padding: chipPadding,
            decoration: BoxDecoration(
              color: streakColor.withValues(alpha: isDark ? 0.18 : 0.13),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: streakColor.withValues(alpha: isInDanger ? 0.6 : 0.32),
                width: isInDanger ? 1.5 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isInDanger ? '⚠️' : '🔥',
                  style: const TextStyle(fontSize: 16, height: 1.0),
                ),
                const SizedBox(width: 5),
                Text(
                  '$streak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: streakColor,
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
                      _initials(account.displayName),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: avatarRadius * 0.65,
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

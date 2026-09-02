import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_badge.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/productivity_streak_service.dart';
import '../../widgets/achievement_badge_art.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _streakService = ProductivityStreakService();
  static const _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final localProfile = context.watch<UserProfileProvider>().profile;
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final habits = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();
    final photo = account.photoUrl;

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
    final earned = badges
        .where((badge) => badge.achieved)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundImage: photo == null ? null : NetworkImage(photo),
              child: photo == null
                  ? Text(
                      _initials(account.displayName),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            account.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            account.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _AccountInfoCard(
            accountType: account.signedInWithGoogle ? 'Google' : 'Email',
            verified: account.emailVerified,
            totalFocus: _formatDuration(focus.totalStoredFocusDuration),
            nationality: localProfile.nationality,
            birthday: localProfile.birthday,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Achievements',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${earned.length}/${badges.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _UnlockedBadgeStrip(badges: earned),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.push('/badges'),
            icon: const FaIcon(FontAwesomeIcons.medal, size: 16),
            label: const Text('Badge showcase'),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => context.go('/?tab=settings'),
            icon: const FaIcon(FontAwesomeIcons.gear, size: 16),
            label: const Text('Account settings'),
          ),
        ],
      ),
    );
  }
}

class _UnlockedBadgeStrip extends StatelessWidget {
  const _UnlockedBadgeStrip({required this.badges});
  final List<AchievementBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Your earned badges will appear here.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final badge = badges[index];
          return SizedBox(
            width: 84,
            child: Column(
              children: [
                AchievementBadgeArt(badge: badge, size: 68, showLock: false),
                const SizedBox(height: 5),
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.accountType,
    required this.verified,
    required this.totalFocus,
    required this.nationality,
    required this.birthday,
  });

  final String accountType;
  final bool verified;
  final String totalFocus;
  final String nationality;
  final DateTime? birthday;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ProfileRow(
            icon: FontAwesomeIcons.user,
            label: 'Account',
            value: accountType,
          ),
          _divider(context),
          _ProfileRow(
            icon: FontAwesomeIcons.envelope,
            label: 'Email',
            value: verified ? 'Verified' : 'Not verified',
          ),
          _divider(context),
          _ProfileRow(
            icon: FontAwesomeIcons.flag,
            label: 'Nationality',
            value: nationality.trim().isEmpty ? '—' : nationality,
          ),
          _divider(context),
          _ProfileRow(
            icon: FontAwesomeIcons.cakeCandles,
            label: 'Birthday',
            value: birthday == null
                ? '—'
                : DateFormat('MMM d').format(birthday!),
          ),
          _divider(context),
          _ProfileRow(
            icon: FontAwesomeIcons.stopwatch,
            label: 'Total focus',
            value: totalFocus,
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).dividerColor);
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final FaIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: FaIcon(icon, size: 17),
        title: Text(label),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

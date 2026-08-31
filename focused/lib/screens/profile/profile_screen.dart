import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_badge.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
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
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final photo = account.photoUrl;

    final activityDates = <DateTime>{
      ...tasks.completionActivityDates(),
      ...focus.focusActivityDates(),
    };
    final longestStreak = _streakService.calculateLongestStreak(
      activityDates: activityDates,
    );
    final badges = _achievementService.buildBadges(
      longestStreak: longestStreak,
      longestLinkedTaskSession: focus.longestLinkedTaskSessionFocusDuration,
      totalFocus: focus.totalStoredFocusDuration,
    );
    final earned = badges.where((badge) => badge.achieved).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Badges',
            onPressed: () => context.push('/badges'),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            account.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 26),
          _BadgeShowcase(
            badges: earned,
            totalBadgeCount: badges.length,
            onTap: () => context.push('/badges'),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                _ProfileRow(
                  icon: account.signedInWithGoogle
                      ? Icons.account_circle_outlined
                      : Icons.alternate_email_rounded,
                  label: 'Account',
                  value: account.signedInWithGoogle
                      ? 'Google account'
                      : 'Email account',
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _ProfileRow(
                  icon: account.emailVerified
                      ? Icons.verified_rounded
                      : Icons.mark_email_unread_outlined,
                  label: 'Email',
                  value: account.emailVerified ? 'Verified' : 'Not verified',
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _ProfileRow(
                  icon: Icons.timer_outlined,
                  label: 'Total focus',
                  value: _formatDuration(focus.totalStoredFocusDuration),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => context.go('/?tab=settings'),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Account settings'),
          ),
        ],
      ),
    );
  }
}

class _BadgeShowcase extends StatelessWidget {
  const _BadgeShowcase({
    required this.badges,
    required this.totalBadgeCount,
    required this.onTap,
  });

  final List<AchievementBadge> badges;
  final int totalBadgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = badges.take(4).toList(growable: false);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Badge showcase',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    '${badges.length}/$totalBadgeCount',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                Text(
                  'Your unlocked badges will appear here.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: shown
                      .map(
                        (badge) => AchievementBadgeArt(
                          badge: badge,
                          size: 64,
                          showLock: false,
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
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

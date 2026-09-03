import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_badge.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/productivity_streak_service.dart';
import '../../widgets/achievement_badge_art.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _streakService = ProductivityStreakService();
  static const _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.profile;
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final habits = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();
    final friendsProvider = context.watch<FriendsProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final photo = account.photoUrl;
    final streak = math.max(
      _streakService.calculateCurrentStreak(
        now: DateTime.now(),
        activityDates: {
          ...tasks.completionActivityDates(),
          ...focus.focusActivityDates(),
          ...habits.habitCompletionDates(),
        },
      ),
      userStats.syncedStreakDays,
    );

    final localTotalFocus = focus.totalStoredFocusDuration;
    final effectiveTotalFocus = localTotalFocus > userStats.syncedFocusDuration
        ? localTotalFocus
        : userStats.syncedFocusDuration;

    final badges = _achievementService.buildBadges(
      longestStreak: userStats.syncedLongestStreak,
      longestLinkedTaskSession: focus.longestLinkedTaskSessionFocusDuration,
      totalFocus: effectiveTotalFocus,
      unlockedBadgeIds: userStats.unlockedBadgeIds,
    );
    final earned = badges
        .where((badge) => badge.achieved)
        .toList(growable: false);

    final followingCount = friendsProvider.following.length;
    final followersCount = friendsProvider.followers.length;
    final xp = userStats.xpPoints;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          profile.displayName.isNotEmpty
              ? profile.displayName
              : account.displayName,
          style: TextStyle(
            color: isDark ? Colors.white : scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: isDark ? Colors.white : scheme.onSurface,
            ),
            tooltip: 'Share Profile',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Profile link copied: focused.app/${profile.handle}',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : scheme.onSurface,
            ),
            tooltip: 'Account Settings',
            onPressed: () => SettingsScreen.editProfile(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
        children: [
          // ── Clean Big Avatar (no edit overlay icon) ──
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF58CC02), // Duolingo green
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white : scheme.primary,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF58CC02).withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: photo != null
                  ? ClipOval(child: Image.network(photo, fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        _initials(profile.displayName),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── @Username and Joined Year (tappable to edit) ──
          Center(
            child: InkWell(
              onTap: () => _showEditUsernameDialog(
                context,
                profileProvider,
                account.user?.uid,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${profile.handle.toUpperCase()} • Joined in ${profile.joinedYear}',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      color: isDark
                          ? const Color(0xFF77878F)
                          : scheme.onSurfaceVariant,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Social Strip (Only Following & Followers) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Following Count
              InkWell(
                onTap: () => context.push('/friends?tab=following'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$followingCount',
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Following',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF77878F)
                              : scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: scheme.outlineVariant),
              // Followers Count
              InkWell(
                onTap: () => context.push('/friends?tab=followers'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$followersCount',
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Followers',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF77878F)
                              : scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Big "+ Add Friends" Button (Theme Aligned) ──
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHigh,
                side: BorderSide(color: scheme.outlineVariant, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => context.push('/friends/add'),
              icon: const Icon(
                Icons.person_add_rounded,
                color: Color(0xFF1CB0F6),
              ),
              label: const Text(
                'Add Friends',
                style: TextStyle(
                  color: Color(0xFF1CB0F6),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Overview Section ("সংক্ষিপ্ত বিবরণ") ──
          Text(
            'Overview',
            style: TextStyle(
              color: isDark ? Colors.white : scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              _StatGridCard(
                icon: '🔥',
                value: '$streak Days',
                label: 'Streak',
                isDark: isDark,
              ),
              _StatGridCard(
                iconWidget: const Icon(
                  Icons.center_focus_strong_rounded,
                  size: 26,
                  color: Color(0xFF1CB0F6),
                ),
                value: _formatDuration(effectiveTotalFocus),
                label: 'Total Focus',
                isDark: isDark,
              ),
              _StatGridCard(
                icon: '🏆',
                value: '${earned.length} Badges',
                label: 'Badges Earned',
                isDark: isDark,
              ),
              _StatGridCard(
                icon: '⚡',
                value: '$xp Points',
                label: 'XP Points',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Friend Streaks ("বন্ধুত্বের ধারাবাহিকতা") ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Friend Streaks',
                  style: TextStyle(
                    color: isDark ? Colors.white : scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/friends'),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: Color(0xFF1CB0F6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FriendStreaksStrip(friendsProvider: friendsProvider, isDark: isDark),
          const SizedBox(height: 32),

          // ── Monthly Badges ("মাসিক ব্যাজ") ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Badges',
                  style: TextStyle(
                    color: isDark ? Colors.white : scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  size: 16,
                ),
                onPressed: () => context.push('/badges'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DuolingoBadgeRow(badges: badges, isDark: isDark),
        ],
      ),
    );
  }

  static void _showEditUsernameDialog(
    BuildContext context,
    UserProfileProvider provider,
    String? uid,
  ) {
    final controller = TextEditingController(text: provider.profile.username);
    String? errorText;
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scheme = Theme.of(context).colorScheme;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A282F) : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Edit Username',
              style: TextStyle(
                color: isDark ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a unique handle so friends can find and nudge you.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFAFBBC1)
                        : scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: TextStyle(
                    color: isDark ? Colors.white : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    prefixText: '@ ',
                    prefixStyle: const TextStyle(
                      color: Color(0xFF1CB0F6),
                      fontWeight: FontWeight.w900,
                    ),
                    errorText: errorText,
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF1CB0F6),
                        width: 2,
                      ),
                    ),
                    hintText: 'your_username',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF77878F)
                          : scheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setState(() => errorText = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFAFBBC1)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58CC02),
                ),
                onPressed: isChecking
                    ? null
                    : () async {
                        final newUsername = controller.text.trim().replaceAll(
                          '@',
                          '',
                        );
                        if (newUsername.isEmpty) return;

                        if (newUsername.length < 3) {
                          setState(
                            () => errorText =
                                'Username must be at least 3 characters',
                          );
                          return;
                        }

                        // Check uniqueness if changed
                        if (newUsername != provider.profile.username) {
                          setState(() => isChecking = true);
                          final isAvailable = await context
                              .read<FriendsProvider>()
                              .checkUsernameAvailability(newUsername);
                          setState(() => isChecking = false);

                          if (!isAvailable) {
                            setState(
                              () => errorText =
                                  'Username @$newUsername is already taken',
                            );
                            return;
                          }
                        }

                        await provider.updateProfile(
                          displayName: provider.profile.displayName,
                          email: provider.profile.email,
                          username: newUsername,
                        );

                        // Update in friends service if signed in
                        if (uid != null && ctx.mounted) {
                          ctx.read<FriendsProvider>().initForUser(uid);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Handle',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Overview Stat Grid Card (Adaptive) ──
class _StatGridCard extends StatelessWidget {
  final String? icon;
  final Widget? iconWidget;
  final String value;
  final String label;
  final bool isDark;

  const _StatGridCard({
    this.icon,
    this.iconWidget,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          iconWidget ?? Text(icon ?? '', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF77878F)
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friend Streaks Strip ("বন্ধুত্বের ধারাবাহিকতা") ──
class _FriendStreaksStrip extends StatelessWidget {
  final FriendsProvider friendsProvider;
  final bool isDark;

  const _FriendStreaksStrip({
    required this.friendsProvider,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final friends = friendsProvider.following;
    final scheme = Theme.of(context).colorScheme;

    if (friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Follow friends to track shared streaks and send task reminders!',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFAFBBC1)
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1CB0F6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => context.push('/friends/add'),
              child: const Text(
                'Find',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final friend = friends[i];
          return Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF58CC02),
                backgroundImage: friend.photoUrl != null
                    ? NetworkImage(friend.photoUrl!)
                    : null,
                child: friend.photoUrl == null
                    ? Text(
                        _initials(friend.displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 2),
                  Text(
                    '${friend.streakDays}',
                    style: const TextStyle(
                      color: Color(0xFFFF9600),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Badges Row ──
class _DuolingoBadgeRow extends StatelessWidget {
  final List<AchievementBadge> badges;
  final bool isDark;

  const _DuolingoBadgeRow({required this.badges, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final displayBadges = badges.take(4).toList();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: displayBadges.map((b) {
        return Column(
          children: [
            AchievementBadgeArt(badge: b, size: 64, showLock: !b.achieved),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                b.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: b.achieved
                      ? (isDark ? Colors.white : scheme.onSurface)
                      : (isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant.withOpacity(0.6)),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
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

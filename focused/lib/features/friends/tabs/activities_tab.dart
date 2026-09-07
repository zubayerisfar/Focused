import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/best_friend.dart';
import '../providers/friends_provider.dart';

class ActivitiesTab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onFindFriends;

  const ActivitiesTab({
    super.key,
    required this.isDark,
    required this.onFindFriends,
  });

  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Update countdown timers every 30 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = context.watch<FriendsProvider>();
    final bestFriends = friendsProvider.bestFriends;
    final scheme = Theme.of(context).colorScheme;

    if (bestFriends.isEmpty) {
      return _buildEmptyState(context, scheme);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Best Friends Streaks',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white : scheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 5 Vertical Slots (filled tiles + empty dashed slots)
        for (int i = 0; i < 5; i++)
          if (i < bestFriends.length)
            _buildBestFriendTile(context, bestFriends[i], scheme)
          else
            _buildEmptySlotTile(context, i + 1, scheme),
      ],
    );
  }

  /// 0 Best Friends Onboarding Empty State
  Widget _buildEmptyState(BuildContext context, ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/friendship_icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.people_outline_rounded,
                size: 90,
                color: Color(0xFF1CB0F6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Make friends with people to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: widget.isDark ? Colors.white : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick up to 5 best friends to build unbroken friendship streaks together! Send daily nudges or 25 EXP gifts to keep your streak alive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? const Color(0xFF77878F)
                    : scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1CB0F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              onPressed: () => _openPickFriendSheet(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text(
                'Start Friendship Streak',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filled Slot: Vertical Best Friend Card
  Widget _buildBestFriendTile(
    BuildContext context,
    BestFriend friend,
    ColorScheme scheme,
  ) {
    final isAtRisk = friend.isAtRisk;
    final hasInteracted = friend.hasInteractedInCurrentCycle;

    final ringColor = isAtRisk
        ? const Color(0xFFEF4444)
        : (hasInteracted ? const Color(0xFF58CC02) : const Color(0xFF1CB0F6));

    final timeRemainingStr = isAtRisk
        ? _formatHoursMinutes(friend.riskTimeRemaining)
        : _formatHoursMinutes(friend.cycleTimeRemaining);

    final firstName = friend.displayName.trim().split(RegExp(r'\s+')).first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              context.push('/profile/view', extra: friend.toFriendUser()),
          onLongPress: () => _confirmRemoveBestFriend(context, friend),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isAtRisk
                  ? (widget.isDark
                        ? const Color(0xFF2A1515)
                        : const Color(0xFFFFF0F0))
                  : scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAtRisk
                    ? const Color(0xFFEF4444)
                    : scheme.outlineVariant,
                width: isAtRisk ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 2.2),
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF1CB0F6),
                        backgroundImage:
                            friend.photoUrl != null &&
                                friend.photoUrl!.isNotEmpty
                            ? NetworkImage(friend.photoUrl!)
                            : null,
                        child:
                            friend.photoUrl == null || friend.photoUrl!.isEmpty
                            ? Text(
                                friend.displayName.isNotEmpty
                                    ? friend.displayName[0].toUpperCase()
                                    : 'F',
                                style: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Friend info & countdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: widget.isDark
                                        ? Colors.white
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF9600,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildFriendshipBadge(friend.streakDays),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${friend.streakDays} days',
                                      style: const TextStyle(
                                        fontFamily: 'Quicksand',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: Color(0xFFFF9600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAtRisk
                                ? 'Streak at risk • $timeRemainingStr left'
                                : (hasInteracted
                                      ? 'Interacted • Next cycle in $timeRemainingStr'
                                      : '$timeRemainingStr left to interact'),
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: widget.isDark
                                  ? const Color(0xFF77878F)
                                  : scheme.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Action Buttons (Nudge & 25 EXP Gift)
                    Consumer<FriendsProvider>(
                      builder: (context, friendsProvider, _) {
                        final canNudge = friendsProvider.canNudgeFriend(
                          friend.uid,
                        );
                        final canGift = friendsProvider.canGiftFriend(
                          friend.uid,
                        );
                        final hasNudged = friendsProvider.hasNudgedToday(
                          friend.uid,
                        );
                        final hasGifted = friendsProvider.hasGiftedToday(
                          friend.uid,
                        );

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nudge Button
                            IconButton(
                              icon: Opacity(
                                opacity: canNudge ? 1.0 : 0.35,
                                child: SvgPicture.asset(
                                  'assets/icon/hand_wave.svg',
                                  width: 26,
                                  height: 26,
                                ),
                              ),
                              tooltip: hasNudged
                                  ? 'Already nudged today (resets at midnight)'
                                  : (canNudge
                                        ? 'Send Nudge'
                                        : 'Daily limit of 5 reached'),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                              onPressed: canNudge
                                  ? () => _handleNudge(context, friend)
                                  : null,
                            ),
                            const SizedBox(width: 2),

                            // 25 EXP Gift Button
                            IconButton(
                              icon: Opacity(
                                opacity: canGift ? 1.0 : 0.35,
                                child: SvgPicture.asset(
                                  'assets/icon/gift_box_icon.svg',
                                  width: 26,
                                  height: 26,
                                ),
                              ),
                              tooltip: hasGifted
                                  ? 'Already sent gift today (resets at midnight)'
                                  : (canGift
                                        ? 'Send 25 EXP Gift'
                                        : 'Daily limit of 5 reached'),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                              onPressed: canGift
                                  ? () => _handleSend25Exp(context, friend)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                // At Risk Banner with Ad Restore Action
                if (isAtRisk) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Streak at risk! Watch ad to restore friendship',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _handleRestoreWithAd(context, friend),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Restore',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendshipBadge(int streakDays) {
    if (streakDays >= 365) {
      return Image.asset(
        'assets/badges/365_days_friendship_badge.png',
        width: 20,
        height: 20,
      );
    } else if (streakDays >= 100) {
      return Image.asset(
        'assets/badges/100_days_friendship_badge.png',
        width: 20,
        height: 20,
      );
    } else if (streakDays >= 30) {
      return Image.asset(
        'assets/badges/30_days_friendship_badge.png',
        width: 20,
        height: 20,
      );
    }
    return SvgPicture.asset(
      'assets/badges/friendship_badge.svg',
      width: 18,
      height: 18,
    );
  }

  /// Empty Slot: Grayed Out Add Card
  Widget _buildEmptySlotTile(
    BuildContext context,
    int slotNumber,
    ColorScheme scheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openPickFriendSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF131722).withValues(alpha: 0.5)
                : scheme.surfaceContainerLowest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF2A3447).withValues(alpha: 0.6)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            color: widget.isDark
                ? const Color(0xFF475569)
                : scheme.onSurfaceVariant.withValues(alpha: 0.4),
            size: 28,
          ),
        ),
      ),
    );
  }

  // ── Actions ──

  Future<void> _handleNudge(BuildContext context, BestFriend friend) async {
    final friendsProvider = context.read<FriendsProvider>();
    final ok = await friendsProvider.nudgeBestFriend(friend);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            ok
                ? '🔔 Sent streak nudge to ${friend.displayName}! (+streak active)'
                : 'Daily reminder limit reached.',
          ),
        ),
      );
    }
  }

  Future<void> _handleSend25Exp(BuildContext context, BestFriend friend) async {
    final friendsProvider = context.read<FriendsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Send 25 EXP Gift',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Send 25 EXP to ${friend.displayName}? This will count towards your daily friendship interaction and costs 25 EXP.',
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF58CC02),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Gift'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await friendsProvider.send25ExpToBestFriend(friend);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok
                ? const Color(0xFF58CC02)
                : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text(
              ok
                  ? '🎉 Sent 25 EXP gift to ${friend.displayName}! Streak updated.'
                  : 'Insufficient EXP balance or daily limit reached.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRestoreWithAd(
    BuildContext context,
    BestFriend friend,
  ) async {
    final friendsProvider = context.read<FriendsProvider>();
    final ok = await friendsProvider.restoreBestFriendStreakWithAd(friend);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok
              ? const Color(0xFF58CC02)
              : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            ok
                ? '✨ Friendship streak restored with ${friend.displayName}!'
                : 'Could not restore streak.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveBestFriend(
    BuildContext context,
    BestFriend friend,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Best Friend?',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${friend.displayName}? You will lose all your activities and your ${friend.streakDays}-day friendship streak with them forever.',
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<FriendsProvider>().removeBestFriend(friend.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text('Removed ${friend.displayName} from Best Friends.'),
          ),
        );
      }
    }
  }

  void _openPickFriendSheet(BuildContext context) {
    final friendsProvider = context.read<FriendsProvider>();
    final following = friendsProvider.following;
    final followers = friendsProvider.followers;
    final followerUids = followers.map((f) => f.uid).toSet();
    final existingBfUids = friendsProvider.bestFriends
        .map((bf) => bf.uid)
        .toSet();
    // Only mutual friends (both users follow each other) who are not already Best Friends
    final eligibleFriends = following
        .where(
          (f) =>
              followerUids.contains(f.uid) && !existingBfUids.contains(f.uid),
        )
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a Friend',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a mutual friend (who follows you back) to start a Best Friends streak:',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            if (eligibleFriends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No mutual friends found.\nYou and your friend must follow each other to start a Best Friends streak!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: eligibleFriends.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final friend = eligibleFriends[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1CB0F6),
                        backgroundImage: friend.photoUrl != null
                            ? NetworkImage(friend.photoUrl!)
                            : null,
                        child: friend.photoUrl == null
                            ? Text(
                                friend.displayName.isNotEmpty
                                    ? friend.displayName[0]
                                    : 'F',
                              )
                            : null,
                      ),
                      title: Text(
                        friend.displayName,
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(friend.handle),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1CB0F6),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await friendsProvider.addBestFriend(friend);
                        },
                        child: const Text('Add'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatHoursMinutes(Duration d) {
    if (d.inMinutes <= 0) return '0m';
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }
}

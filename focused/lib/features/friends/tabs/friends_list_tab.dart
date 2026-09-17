import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../models/friend_user.dart';

class FriendsListTab extends StatelessWidget {
  final List<FriendUser> friends;
  final bool isFollowingTab;
  final bool isDark;
  final bool canSendReminder;
  final bool Function(FriendUser)? canSendReminderTo;
  final bool canSendGift;
  final Function(FriendUser) onSendReminder;
  final Function(FriendUser)? onSendExp;
  final Function(FriendUser)? onUnfollow;
  final Function(FriendUser)? onFollowBack;

  const FriendsListTab({
    super.key,
    required this.friends,
    required this.isFollowingTab,
    required this.isDark,
    required this.canSendReminder,
    this.canSendReminderTo,
    this.canSendGift = true,
    required this.onSendReminder,
    this.onSendExp,
    this.onUnfollow,
    this.onFollowBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👥', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 10),
            Text(
              isFollowingTab
                  ? 'You are not following anyone yet.'
                  : 'No followers yet.',
              style: TextStyle(
                color: isDark ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search friends by username to pair up and track habits!',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF77878F)
                    : scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1CB0F6),
              ),
              onPressed: () => context.push('/friends/add'),
              child: const Text(
                'Find Friends',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final friend = friends[i];
        return InkWell(
          onTap: () => context.push('/profile/view', extra: friend),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141622) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFF64748B).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF58CC02),
                  backgroundImage:
                      friend.photoUrl != null && friend.photoUrl!.isNotEmpty
                      ? NetworkImage(friend.photoUrl!)
                      : null,
                  onBackgroundImageError: friend.photoUrl != null
                      ? (_, __) {}
                      : null,
                  child: friend.photoUrl == null || friend.photoUrl!.isEmpty
                      ? Text(
                          friend.displayName.isNotEmpty
                              ? friend.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              friend.handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF77878F)
                                    : scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (friend.streakDays > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '🔥 ${friend.streakDays}',
                              style: const TextStyle(
                                color: Color(0xFFFF9600),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isFollowingTab) ...[
                      SizedBox(
                        height: 36,
                        child: friend.isFollowing
                            ? OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF37464F)
                                        : scheme.outlineVariant,
                                  ),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                ),
                                onPressed: () => onUnfollow?.call(friend),
                                child: const Text(
                                  'Following',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1CB0F6),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                ),
                                onPressed: () => onFollowBack?.call(friend),
                                child: const Text(
                                  'Follow Back',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Nudge reminder button ONLY shown in Following tab
                    if (isFollowingTab) ...[
                      // Nudge Reminder Button (Custom Svg & Enlarged)
                      Builder(
                        builder: (context) {
                          final canSend = canSendReminderTo != null
                              ? canSendReminderTo!(friend)
                              : canSendReminder;
                          return IconButton(
                            icon: Opacity(
                              opacity: canSend ? 1.0 : 0.35,
                              child: SvgPicture.asset(
                                'assets/icon/hand_wave.svg',
                                width: 26,
                                height: 26,
                              ),
                            ),
                            tooltip: canSend
                                ? 'Send Task Reminder'
                                : (canSendReminder
                                      ? 'Already nudged today (resets at midnight)'
                                      : 'Daily limit of 5 reached'),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            onPressed: canSend
                                ? () => onSendReminder(friend)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 2),
                    ],
                    // More Actions (Only on Following tab - removed from Followers tab)
                    if (isFollowingTab)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark
                              ? const Color(0xFF77878F)
                              : scheme.onSurfaceVariant,
                          size: 22,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        color: scheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (action) {
                          if (action == 'unfollow') onUnfollow?.call(friend);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'unfollow',
                            child: Text(
                              'Unfollow',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

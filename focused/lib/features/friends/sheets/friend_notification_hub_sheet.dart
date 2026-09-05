import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../providers/friends_provider.dart';

class FriendNotificationHubSheet extends StatelessWidget {
  const FriendNotificationHubSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final friendsProvider = context.watch<FriendsProvider>();
    final notices = friendsProvider.groupNotices;
    final unclaimedGifts = friendsProvider.unclaimedGifts;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2B3D47) : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SvgPicture.asset(
                'assets/icon/group_tab_notification_icon.svg',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Squad Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
              if (unclaimedGifts.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final claimed = await friendsProvider.claimAllExpGifts();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF58CC02),
                          content: Text('🎉 Claimed +$claimed EXP!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Claim All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notices.isEmpty && unclaimedGifts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 54,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'All caught up!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have no pending gifts or group notices.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF77878F)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (unclaimedGifts.isNotEmpty) ...[
                        Text(
                          'GIFTS WAITING',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF58CC02),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...unclaimedGifts.map(
                          (g) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF58CC02,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFF58CC02,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    '🎁',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '+${g.amount} EXP from ${g.fromName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      Text(
                                        'Ready to claim & level up!',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF58CC02),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => friendsProvider.claimExp(g),
                                  child: const Text('Claim'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (notices.isNotEmpty) ...[
                        Text(
                          'SQUAD ACTIVITY',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1CB0F6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...notices.map(
                          (n) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1CB0F6,
                                    ).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.group_add_rounded,
                                    color: Color(0xFF1CB0F6),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Added to "${n['groupName'] ?? 'Squad'}"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'By ${n['creatorName'] ?? 'A friend'} • Squad active',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

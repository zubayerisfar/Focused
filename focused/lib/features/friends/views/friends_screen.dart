import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/friend_user.dart';
import '../../tasks/models/task_group.dart';
import '../../auth/providers/account_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/task_mate_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/widgets/profile_streak_xp_bar.dart';

import '../tabs/task_mates_tab.dart';
import '../tabs/friends_list_tab.dart';
import '../widgets/claim_exp_banner.dart';
import '../widgets/partner_quest_card.dart';
import '../sheets/friend_notification_hub_sheet.dart';
import '../sheets/create_squad_sheet.dart';
import '../sheets/assign_squad_task_sheet.dart';
import '../widgets/squad_task_actions.dart';

class FriendsScreen extends StatefulWidget {
  final int initialTabIndex;
  const FriendsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _hasCheckedLoginGifts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnclaimedGiftsPopup();
    });
  }

  void _checkUnclaimedGiftsPopup() {
    if (!mounted || _hasCheckedLoginGifts) return;
    _hasCheckedLoginGifts = true;
    final friendsProvider = context.read<FriendsProvider>();
    final gifts = friendsProvider.unclaimedGifts;
    if (gifts.isNotEmpty) {
      final first = gifts.first;
      final totalXp = gifts.fold<int>(0, (sum, g) => sum + g.amount);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              SvgPicture.asset(
                'assets/icon/gift_box_icon.svg',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'EXP Gifts Waiting!',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            gifts.length == 1
                ? '🎁 You received +${first.amount} EXP from ${first.fromName}!'
                : '🎁 You have ${gifts.length} gifts waiting (+total $totalXp EXP) from your friends!',
            style: const TextStyle(fontSize: 14.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF58CC02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'Claim All Now!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final claimed = await friendsProvider.claimAllExpGifts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF58CC02),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      content: Text(
                        '🎉 Claimed +$claimed EXP into your balance!',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_tabController.length != 3) {
      final oldIndex = _tabController.index.clamp(0, 2);
      _tabController.dispose();
      _tabController = TabController(
        length: 3,
        vsync: this,
        initialIndex: oldIndex,
      );
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController.length != 3) {
      final oldIndex = _tabController.index.clamp(0, 2);
      _tabController.dispose();
      _tabController = TabController(
        length: 3,
        vsync: this,
        initialIndex: oldIndex,
      );
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
    final friendsProvider = context.watch<FriendsProvider>();
    final unclaimedGifts = friendsProvider.unclaimedGifts;
    final following = friendsProvider.following;
    final followers = friendsProvider.followers;
    final quest = friendsProvider.partnerQuest;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _tabController.index == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: SizedBox(
                height: 42,
                child: FloatingActionButton.extended(
                  heroTag: 'add_friends_fab',
                  backgroundColor: const Color(0xFF1CB0F6),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  onPressed: () => context.push('/friends/add'),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        title: Text(
          'Friends',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          // Notification Hub Icon with badge
          Builder(
            builder: (ctx) {
              final unreadCount =
                  unclaimedGifts.length +
                  friendsProvider.groupNotices
                      .where((n) => n['read'] == false)
                      .length;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icon/group_tab_notification_icon.svg',
                      width: 28,
                      height: 28,
                    ),
                    tooltip: 'Squad Notifications & Gifts',
                    onPressed: () => _openNotificationHub(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          const ProfileStreakXpBar(showProfile: true, avatarRadius: 20),
          const SizedBox(width: 14),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── CLAIM EXP BUTTON (Shown ONLY when points received from friends!) ──
                  if (unclaimedGifts.isNotEmpty) ...[
                    ...unclaimedGifts.map(
                      (gift) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClaimExpBanner(
                          gift: gift,
                          onClaim: () async {
                            await friendsProvider.claimExp(gift);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF58CC02),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  content: Row(
                                    children: [
                                      const Text(
                                        '🎉',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+${gift.amount} EXP received from ${gift.fromUsername}!',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],

                  // ── PARTNER QUEST CARD ("Quest with a Friend") ──
                  if (quest != null) ...[
                    PartnerQuestCard(
                      quest: quest,
                      isDark: isDark,
                      canSendReminder: friendsProvider.canSendReminder,
                      remindersUsed: friendsProvider.remindersSentToday,
                      onSendReminder: () async {
                        final success = await friendsProvider.sendReminder(
                          quest.partnerUid,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              content: Text(
                                success
                                    ? '🔔 Task reminder sent to ${quest.partnerName}! (${friendsProvider.remindersSentToday}/5 sent today)'
                                    : 'Daily reminder limit of 5 reached for today.',
                              ),
                            ),
                          );
                        }
                      },
                      onSendExp: () => _confirmSendExp(
                        context,
                        quest.partnerUid,
                        quest.partnerName,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── TABS: TASK MATES (FRONT), FOLLOWING & FOLLOWERS ──
                  Container(
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      dividerHeight: 0,
                      indicator: BoxDecoration(
                        color: const Color(0xFF1CB0F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark
                          ? const Color(0xFF77878F)
                          : scheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      tabs: const [
                        Tab(text: 'Task Mates'),
                        Tab(text: 'Following'),
                        Tab(text: 'Followers'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // 1. Task Mates Tab (FRONT)
            TaskMatesTab(
              isDark: isDark,
              onCreateGroup: () => _showCreateGroupDialog(context),
              onAssignTask: (group) => _showAssignTaskSheet(context, group),
              onPickTime: (group, idx) =>
                  _pickScheduleTime(context, group, taskIndex: idx),
              onStartTask: (group, idx) =>
                  _startTask(context, group, taskIndex: idx),
            ),

            // 2. Following Tab
            FriendsListTab(
              friends: following,
              isFollowingTab: true,
              isDark: isDark,
              canSendReminder: friendsProvider.canSendReminder,
              canSendGift: friendsProvider.canSendGift,
              onSendReminder: (f) async {
                final ok = await friendsProvider.sendReminder(f.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        ok
                            ? '🔔 Reminder sent to ${f.displayName}! (${friendsProvider.remindersSentToday}/5 sent today)'
                            : 'Daily limit of 5 reminders reached.',
                      ),
                    ),
                  );
                }
              },
              onSendExp: (f) => _confirmSendExp(context, f.uid, f.displayName),
              onPairQuest: (f) => friendsProvider.pairWithFriend(f),
              onUnfollow: (f) => _confirmUnfollow(context, f),
            ),

            // 3. Followers Tab
            FriendsListTab(
              friends: followers,
              isFollowingTab: false,
              isDark: isDark,
              canSendReminder: friendsProvider.canSendReminder,
              canSendGift: friendsProvider.canSendGift,
              onSendReminder: (_) {},
              onSendExp: (_) {},
              onPairQuest: (f) => friendsProvider.pairWithFriend(f),
              onFollowBack: (f) => friendsProvider.follow(f),
              onUnfollow: (f) => _confirmUnfollow(context, f),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSendExp(
    BuildContext context,
    String targetUid,
    String targetName,
  ) async {
    final stats = context.read<UserStatsProvider>();
    if (stats.xpPoints < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 50 EXP to send a gift.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A282F) : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/icon/gift_box_icon.svg',
              width: 26,
              height: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Send 50 EXP Boost?',
              style: TextStyle(
                color: isDark ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Send 50 EXP to boost $targetName\'s mindset! This will transfer 50 EXP from your balance.',
          style: TextStyle(
            color: isDark ? const Color(0xFFAFBBC1) : scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF77878F)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Send 50 EXP',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<FriendsProvider>().send50Exp(
        targetUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A73E8),
            behavior: SnackBarBehavior.floating,
            content: Text(
              success
                  ? '✨ Sent 50 EXP gift to $targetName!'
                  : 'Could not send EXP gift.',
            ),
          ),
        );
      }
    }
  }

  // ── UNFOLLOW WITH GROUP CLEANUP ──

  Future<void> _confirmUnfollow(BuildContext context, FriendUser friend) async {
    final taskMateProvider = context.read<TaskMateProvider>();
    final friendsProvider = context.read<FriendsProvider>();
    final account = context.read<AccountProvider>();
    final myUid = account.user?.uid ?? '';

    // Find groups shared with this user
    final sharedGroups = taskMateProvider.groups
        .where((g) => g.memberUids.contains(friend.uid))
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A282F) : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Unfollow?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          sharedGroups.isNotEmpty
              ? 'You have ${sharedGroups.length} shared group${sharedGroups.length > 1 ? 's' : ''} with ${friend.displayName}. Unfollowing will permanently destroy ${sharedGroups.length > 1 ? 'these groups' : 'this group'} and remove all shared tasks.'
              : 'Are you sure you want to unfollow ${friend.displayName}?',
          style: TextStyle(
            color: isDark ? const Color(0xFFAFBBC1) : scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: sharedGroups.isNotEmpty
                  ? Colors.red
                  : scheme.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              sharedGroups.isNotEmpty ? 'Unfollow & Destroy Group' : 'Unfollow',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Destroy all shared groups first
      for (final group in sharedGroups) {
        final isCreator = group.createdBy == myUid;
        await taskMateProvider.leaveOrDeleteGroup(
          groupId: group.id,
          isCreator: isCreator,
        );
      }
      if (context.mounted) {
        await friendsProvider.unfollow(friend.uid);
      }
    }
  }

  // ── TASK MATES DIALOGS & ACTIONS ──

  void _showCreateGroupDialog(BuildContext context) {
    showCreateGroupDialog(context);
  }

  void _showAssignTaskSheet(BuildContext context, TaskGroup group) {
    showAssignTaskSheet(context, group);
  }

  Future<void> _pickScheduleTime(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
    GroupActiveTask? task,
  }) {
    return SquadTaskActions.pickScheduleTime(
      context,
      group,
      taskIndex: taskIndex,
      task: task,
    );
  }

  Future<void> _startTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) {
    return SquadTaskActions.startTask(context, group, taskIndex: taskIndex);
  }

  void _openNotificationHub(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final friendsProvider = context.read<FriendsProvider>();
    // Auto-claim all unclaimed gifts when opening the notification tab
    friendsProvider.claimAllExpGifts().then((claimed) {
      if (claimed > 0 && mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF58CC02),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Text('🎉 Auto-claimed +$claimed EXP into your balance!'),
          ),
        );
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FriendNotificationHubSheet(),
    );
  }
}

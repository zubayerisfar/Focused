import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/friend_user.dart';
import '../../models/task_group.dart';
import '../../providers/account_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/task_mate_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/ad_service.dart';
import '../../widgets/profile_streak_xp_bar.dart';

import '../../features/friends/tabs/task_mates_tab.dart';
import '../../features/friends/tabs/friends_list_tab.dart';
import '../../features/friends/widgets/claim_exp_banner.dart';
import '../../features/friends/widgets/partner_quest_card.dart';
import '../../features/friends/sheets/friend_notification_hub_sheet.dart';

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
                        fontWeight: FontWeight.w800,
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
    final friendsProvider = context.read<FriendsProvider>();
    final taskMateProvider = context.read<TaskMateProvider>();
    final account = context.read<AccountProvider>();
    final myUid = account.user?.uid ?? '';
    final friends = friendsProvider.following
        .where((f) => f.uid != myUid)
        .toList();

    final nameController = TextEditingController();
    final selectedFriends = <FriendUser>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scheme = Theme.of(context).colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                          color: isDark
                              ? const Color(0xFF2B3D47)
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icon/group_icon.svg',
                          width: 26,
                          height: 26,
                          colorFilter: ColorFilter.mode(
                            scheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create Task Squad',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Partner with up to 4 friends (up to 5 members total). Squad members can share up to 3 active tasks and earn double EXP (+200 EXP)!',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Squad Name',
                        hintText: 'e.g. Focus Duo, Daily Grind',
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose up to 4 Friends (${selectedFriends.length}/4):',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'You have not followed any friends yet. Follow friends first to create a squad!',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF77878F)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final f = friends[i];
                            final isSelected = selectedFriends.any(
                              (sf) => sf.uid == f.uid,
                            );

                            return CheckboxListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: scheme.surfaceContainerHigh,
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF58CC02),
                                backgroundImage:
                                    f.photoUrl != null && f.photoUrl!.isNotEmpty
                                    ? NetworkImage(f.photoUrl!)
                                    : null,
                                onBackgroundImageError: f.photoUrl != null
                                    ? (_, __) {}
                                    : null,
                                child: f.photoUrl == null || f.photoUrl!.isEmpty
                                    ? Text(
                                        f.displayName.isNotEmpty
                                            ? f.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                f.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                f.handle,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF77878F)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    if (selectedFriends.length < 4) {
                                      selectedFriends.add(f);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Maximum 4 friends can be added (5 members total).',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    selectedFriends.removeWhere(
                                      (sf) => sf.uid == f.uid,
                                    );
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1CB0F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: selectedFriends.isEmpty
                            ? null
                            : () async {
                                final squadName =
                                    nameController.text.trim().isEmpty
                                    ? 'Task Squad'
                                    : nameController.text.trim();
                                Navigator.pop(ctx);
                                final ok = await taskMateProvider.createGroup(
                                  name: squadName,
                                  selectedFriends: selectedFriends,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: ok
                                          ? const Color(0xFF58CC02)
                                          : Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        ok
                                            ? '🎉 Squad "$squadName" created!'
                                            : 'Could not create squad. Max 3 groups allowed.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'Create Squad',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAssignTaskSheet(BuildContext context, TaskGroup group) {
    final taskMateProvider = context.read<TaskMateProvider>();
    final customTaskController = TextEditingController();
    bool isDaily = false;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedStartTime = TimeOfDay.now();
    TimeOfDay selectedEndTime = TimeOfDay(
      hour:
          (TimeOfDay.now().hour + (TimeOfDay.now().minute + 30 >= 60 ? 1 : 0)) %
          24,
      minute: (TimeOfDay.now().minute + 30) % 60,
    );
    int? selectedReminderMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final scheme = Theme.of(ctx).colorScheme;

          String reminderText(int? mins) {
            if (mins == null) return 'No reminder';
            if (mins == 0) return 'At start';
            return '$mins min before';
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2B3D47)
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        'Create Squad Task (${group.activeTasks.length}/3)',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Task Type Selector: Single Task vs Daily Habit
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setSheetState(() => isDaily = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: !isDaily
                                  ? const Color(
                                      0xFF9B51E0,
                                    ).withValues(alpha: isDark ? 0.22 : 0.12)
                                  : scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: !isDaily
                                    ? const Color(0xFF9B51E0)
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                width: !isDaily ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: !isDaily
                                        ? const Color(0xFF9B51E0)
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.task_alt_rounded,
                                    size: 18,
                                    color: !isDaily
                                        ? Colors.white
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Single Task',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: !isDaily
                                              ? (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF6B21A8))
                                              : (isDark
                                                    ? Colors.white70
                                                    : scheme.onSurface),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'One-time quest',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setSheetState(() => isDaily = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDaily
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: isDark ? 0.22 : 0.12)
                                  : scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDaily
                                    ? const Color(0xFF10B981)
                                    : scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                width: isDaily ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDaily
                                        ? const Color(0xFF10B981)
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.repeat_rounded,
                                    size: 18,
                                    color: isDaily
                                        ? Colors.white
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Daily Habit',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDaily
                                              ? (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF047857))
                                              : (isDark
                                                    ? Colors.white70
                                                    : scheme.onSurface),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Recurring daily',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: customTaskController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isDaily ? 'Daily Squad Habit' : 'Task Title',
                      hintText: isDaily
                          ? 'e.g. Daily Coding, Morning Run'
                          : 'e.g. Complete Project Proposal, Math Chapter 4',
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date Picker Row (for one-time task)
                  if (!isDaily) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFF9B51E0),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'EEE, MMM d, yyyy',
                                    ).format(selectedDate),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Start & End Time Pickers
                  Row(
                    children: [
                      // Start Time
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedStartTime,
                            );
                            if (picked != null) {
                              setSheetState(() {
                                selectedStartTime = picked;
                                selectedEndTime = TimeOfDay(
                                  hour:
                                      (picked.hour +
                                          (picked.minute + 30 >= 60 ? 1 : 0)) %
                                      24,
                                  minute: (picked.minute + 30) % 60,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFF9B51E0),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        selectedStartTime.format(ctx),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // End Time
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedEndTime,
                            );
                            if (picked != null) {
                              setSheetState(() => selectedEndTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timelapse_rounded,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Time',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        selectedEndTime.format(ctx),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Reminder Picker
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final chosen = await showModalBottomSheet<int?>(
                        context: ctx,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (rCtx) => SafeArea(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(rCtx).height * 0.7,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.notifications_active_rounded,
                                          color: Color(0xFF9B51E0),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Choose Reminder Time',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : scheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  for (final mins in <int?>[
                                    null,
                                    0,
                                    5,
                                    10,
                                    15,
                                    30,
                                    60,
                                  ])
                                    ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 4,
                                          ),
                                      title: Text(
                                        reminderText(mins),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              selectedReminderMinutes == mins
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                          color: selectedReminderMinutes == mins
                                              ? const Color(0xFF9B51E0)
                                              : (isDark
                                                    ? Colors.white
                                                    : scheme.onSurface),
                                        ),
                                      ),
                                      trailing: selectedReminderMinutes == mins
                                          ? Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF9B51E0),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            )
                                          : null,
                                      onTap: () => Navigator.pop(rCtx, mins),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      setSheetState(() => selectedReminderMinutes = chosen);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFF9B51E0),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reminder',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reminderText(selectedReminderMinutes),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9B51E0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.group_add_rounded),
                      label: Text(
                        isDaily
                            ? 'Create Daily Squad Habit'
                            : 'Create Squad Task',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        final title = customTaskController.text.trim();
                        if (title.isEmpty) return;
                        Navigator.pop(ctx);

                        final ok = await taskMateProvider.assignTask(
                          groupId: group.id,
                          title: title,
                          category: isDaily ? 'Habit' : 'Task',
                          isHabit: isDaily,
                        );

                        if (ok) {
                          final baseDate = isDaily
                              ? DateTime.now()
                              : selectedDate;
                          final scheduledDateTime = DateTime(
                            baseDate.year,
                            baseDate.month,
                            baseDate.day,
                            selectedStartTime.hour,
                            selectedStartTime.minute,
                          );
                          final scheduledEndDateTime = DateTime(
                            baseDate.year,
                            baseDate.month,
                            baseDate.day,
                            selectedEndTime.hour,
                            selectedEndTime.minute,
                          );

                          await taskMateProvider.setMySchedule(
                            groupId: group.id,
                            scheduledTime: scheduledDateTime,
                            scheduledEnd: scheduledEndDateTime,
                            reminderMinutesBefore: selectedReminderMinutes,
                            taskTitle: title,
                            isHabit: isDaily,
                            taskIndex: group.activeTasks.length,
                          );
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: ok
                                  ? const Color(0xFF9B51E0)
                                  : Colors.redAccent,
                              content: Text(
                                ok
                                    ? '⚡ Squad Quest "$title" created!'
                                    : 'This squad already has 3 active tasks.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickScheduleTime(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
    GroupActiveTask? task,
  }) async {
    final taskMateProvider = context.read<TaskMateProvider>();
    final targetTask =
        task ??
        (group.activeTasks.length > taskIndex
            ? group.activeTasks[taskIndex]
            : group.activeTask);
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !context.mounted) return;

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await taskMateProvider.setMySchedule(
      groupId: group.id,
      taskTitle: targetTask?.title ?? 'Task Squad Goal',
      scheduledTime: scheduled,
      taskIndex: taskIndex,
      isHabit: targetTask?.isHabit ?? false,
    );

    if (context.mounted) {
      final syncNote = (targetTask?.isHabit == true)
          ? ' & synced to Habits'
          : ' & added to Today Tasks';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1CB0F6),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '⏰ Scheduled for ${DateFormat('EEE, MMM d • h:mm a').format(scheduled)}$syncNote!',
          ),
        ),
      );
    }
  }

  Future<void> _startTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) async {
    final targetTask = group.activeTasks.length > taskIndex
        ? group.activeTasks[taskIndex]
        : group.activeTask;
    final taskTitle = targetTask?.title ?? 'Squad Goal';

    // Show a quick dialog or bottom sheet offering to jump into Focus Mode or complete
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B3D47)
                      : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Squad Quest: $taskTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Start a dedicated focus session to conquer this task with your squad!',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF58CC02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Start Focus Session',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  onPressed: () => Navigator.pop(bCtx, 'focus'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'I Finished It • Claim EXP',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.pop(bCtx, 'complete'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (action == 'focus') {
      context.push('/focus/setup');
    } else if (action == 'complete') {
      await _completeTask(context, group, taskIndex: taskIndex);
    }
  }

  Future<void> _completeTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) async {
    final taskMateProvider = context.read<TaskMateProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // Show Double XP Offer Dialog
    final shouldWatchVideo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: const [
            Text('🎉', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Squad Task Completed!',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'DOUBLE XP: 400 EXP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'You earned +200 EXP! Watch a quick video to double your reward to 400 EXP and climb the leaderboard faster.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFFAFBBC1)
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(
                    'Claim 200 EXP',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                  label: const Text(
                    'Double to 400',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldWatchVideo == true) {
      // User chose to watch video for double XP (400 EXP)
      AdService.instance.showRewardedAd(
        onUserEarnedReward: (reward) async {
          // Complete task with full 400 EXP
          await taskMateProvider.completeTask(
            groupId: group.id,
            taskIndex: taskIndex,
            xpAward: 400,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFFF8F00),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Row(
                  children: const [
                    Text('⚡', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Awesome! 400 EXP added & synced to your account!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
        onAdDismissed: () async {
          // If ad was dismissed or not ready, ensure task is completed with 200 EXP
          final task = group.activeTasks.length > taskIndex
              ? group.activeTasks[taskIndex]
              : null;
          final sched = task?.memberSchedules[taskMateProvider.currentUid];
          if (sched?.completed != true) {
            await taskMateProvider.completeTask(
              groupId: group.id,
              taskIndex: taskIndex,
              xpAward: 200,
            );
          }
        },
      );
    } else {
      // Standard completion (+200 EXP)
      await taskMateProvider.completeTask(
        groupId: group.id,
        taskIndex: taskIndex,
        xpAward: 200,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF58CC02),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Task Complete!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '+200 EXP added to your account & synced!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
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


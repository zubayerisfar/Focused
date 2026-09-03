import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/exp_gift.dart';
import '../../models/friend_user.dart';
import '../../models/partner_quest.dart';
import '../../models/task_group.dart';
import '../../providers/account_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/task_mate_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../widgets/profile_streak_xp_bar.dart';

class FriendsScreen extends StatefulWidget {
  final int initialTabIndex;
  const FriendsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          heroTag: 'add_friends_fab',
          backgroundColor: const Color(0xFF1CB0F6),
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => context.push('/friends/add'),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text(
            'Add Friend',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        title: Text(
          'Friends',
          style: TextStyle(
            color: isDark ? Colors.white : scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: const [
          ProfileStreakXpBar(showProfile: true, avatarRadius: 18),
          SizedBox(width: 14),
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
                        child: _ClaimExpBanner(
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
                    _PartnerQuestCard(
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
                                    ? '🔔 Task reminder sent to ${quest.partnerName}! (${friendsProvider.remindersSentToday}/3 sent today)'
                                    : 'Daily reminder limit of 3 reached for today.',
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
            _TaskMatesTab(
              isDark: isDark,
              onCreateGroup: () => _showCreateGroupDialog(context),
              onAssignTask: (group) => _showAssignTaskSheet(context, group),
              onPickTime: (group, idx) =>
                  _pickScheduleTime(context, group, taskIndex: idx),
              onCompleteTask: (group, idx) =>
                  _completeTask(context, group, taskIndex: idx),
            ),

            // 2. Following Tab
            _FriendsListTab(
              friends: following,
              isFollowingTab: true,
              isDark: isDark,
              canSendReminder: friendsProvider.canSendReminder,
              onSendReminder: (f) async {
                final ok = await friendsProvider.sendReminder(f.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        ok
                            ? '🔔 Reminder sent to ${f.displayName}!'
                            : 'Daily limit of 3 reminders reached.',
                      ),
                    ),
                  );
                }
              },
              onSendExp: (f) => _confirmSendExp(context, f.uid, f.displayName),
              onPairQuest: (f) => friendsProvider.pairWithFriend(f),
              onUnfollow: (f) => friendsProvider.unfollow(f.uid),
            ),

            // 3. Followers Tab
            _FriendsListTab(
              friends: followers,
              isFollowingTab: false,
              isDark: isDark,
              canSendReminder: friendsProvider.canSendReminder,
              onSendReminder: (f) async {
                final ok = await friendsProvider.sendReminder(f.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        ok
                            ? '🔔 Reminder sent to ${f.displayName}!'
                            : 'Daily limit of 3 reminders reached.',
                      ),
                    ),
                  );
                }
              },
              onSendExp: (f) => _confirmSendExp(context, f.uid, f.displayName),
              onPairQuest: (f) => friendsProvider.pairWithFriend(f),
              onFollowBack: (f) => friendsProvider.follow(f),
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
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
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
                    const Text('🤝', style: TextStyle(fontSize: 26)),
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
                  'Choose up to 2 Friends (${selectedFriends.length}/2):',
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
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                          title: Text(
                            f.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : scheme.onSurface,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                            final squadName = nameController.text.trim().isEmpty
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
          );
        },
      ),
    );
  }

  void _showAssignTaskSheet(BuildContext context, TaskGroup group) {
    final taskProvider = context.read<TaskProvider>();
    final taskMateProvider = context.read<TaskMateProvider>();
    final customTaskController = TextEditingController();
    bool isHabit = false;

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

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
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
                    const Text('⚡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(
                      'Assign Squad Task (${group.activeTasks.length}/3)',
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
                  'Upload up to 3 tasks to "${group.name}". Each member sets their own timer, auto-syncing to their task list or habits, and earns +200 EXP!',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF77878F)
                        : scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),

                // Task Type Selector: Task vs Habit
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('📋 Task'),
                      selected: !isHabit,
                      selectedColor: const Color(
                        0xFF1CB0F6,
                      ).withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setSheetState(() => isHabit = false);
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('🌱 Habit (Auto-sync)'),
                      selected: isHabit,
                      selectedColor: const Color(
                        0xFF58CC02,
                      ).withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setSheetState(() => isHabit = true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: customTaskController,
                  decoration: InputDecoration(
                    labelText: isHabit ? 'Habit Title' : 'Custom Task Title',
                    hintText: isHabit
                        ? 'e.g. Daily 20m Reading, Morning Walk'
                        : 'e.g. Finish Chapter 4, Do 30m Workout',
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isHabit
                          ? const Color(0xFF58CC02)
                          : const Color(0xFF1CB0F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      isHabit ? 'Upload Squad Habit' : 'Upload Squad Task',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () async {
                      final title = customTaskController.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);
                      final ok = await taskMateProvider.assignTask(
                        groupId: group.id,
                        title: title,
                        category: isHabit ? 'Habit' : 'Task',
                        isHabit: isHabit,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok
                                ? const Color(0xFF58CC02)
                                : Colors.redAccent,
                            content: Text(
                              ok
                                  ? '⚡ Task uploaded to "${group.name}"!'
                                  : 'This squad already has 3 active tasks.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (taskProvider.tasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Or pick from your personal tasks:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: taskProvider.tasks.take(8).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final t = taskProvider.tasks[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: scheme.surfaceContainerHigh,
                          title: Text(
                            t.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final ok = await taskMateProvider.assignTask(
                              groupId: group.id,
                              title: t.title,
                              category: isHabit ? 'Habit' : 'Task',
                              isHabit: isHabit,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: ok
                                      ? const Color(0xFF58CC02)
                                      : Colors.redAccent,
                                  content: Text(
                                    ok
                                        ? '⚡ Task "${t.title}" uploaded to squad!'
                                        : 'This squad already has 3 active tasks.',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
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

  Future<void> _completeTask(
    BuildContext context,
    TaskGroup group, {
    int taskIndex = 0,
  }) async {
    final taskMateProvider = context.read<TaskMateProvider>();

    await taskMateProvider.completeTask(
      groupId: group.id,
      taskIndex: taskIndex,
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
                      'Double reward +200 EXP added to your balance!',
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

// ── TASK MATES TAB ──
class _TaskMatesTab extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreateGroup;
  final Function(TaskGroup) onAssignTask;
  final Function(TaskGroup, int) onPickTime;
  final Function(TaskGroup, int) onCompleteTask;

  const _TaskMatesTab({
    required this.isDark,
    required this.onCreateGroup,
    required this.onAssignTask,
    required this.onPickTime,
    required this.onCompleteTask,
  });

  @override
  Widget build(BuildContext context) {
    final taskMateProvider = Provider.of<TaskMateProvider?>(context);
    final account = context.watch<AccountProvider>();
    final currentUid = account.user?.uid ?? '';
    final scheme = Theme.of(context).colorScheme;

    if (taskMateProvider == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.restart_alt_rounded,
                size: 48,
                color: Color(0xFF1CB0F6),
              ),
              const SizedBox(height: 12),
              Text(
                'Hot-Restart Needed',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A new provider was added. Please press "R" in your terminal (or stop and re-run) to load Task Mates!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = taskMateProvider.groups;

    if (taskMateProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1CB0F6)),
      );
    }

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1CB0F6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🤝', style: TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Task Squads Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Team up with up to 4 friends (up to 5 members total)! Upload up to 3 shared tasks/habits and earn double EXP (+200 EXP) when finished.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1CB0F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                onPressed: onCreateGroup,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text(
                  'Create a Task Squad',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(
          children: [
            Text(
              'YOUR SQUADS (${groups.length}/3)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFF77878F)
                    : scheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (taskMateProvider.canCreateGroup)
              TextButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF1CB0F6),
                ),
                label: const Text(
                  'New Squad',
                  style: TextStyle(
                    color: Color(0xFF1CB0F6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Group Cards
        ...groups.map((group) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Header (Name & Members)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1CB0F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🤝', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${group.members.length} members',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF77878F)
                                  : scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                      ),
                      color: scheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (action) {
                        if (action == 'leave') {
                          taskMateProvider.leaveOrDeleteGroup(
                            groupId: group.id,
                            isCreator: group.isCreator(currentUid),
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'leave',
                          child: Text(
                            group.isCreator(currentUid)
                                ? 'Delete Squad'
                                : 'Leave Squad',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Tasks Section (Up to 3 tasks)
                if (group.activeTasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'No Active Tasks',
                          style: TextStyle(
                            color: isDark ? Colors.white : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload up to 3 shared tasks/habits for the squad to conquer together!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFAFBBC1)
                                : scheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1CB0F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => onAssignTask(group),
                          icon: const Icon(Icons.add_task_rounded, size: 18),
                          label: const Text(
                            'Upload Task (0/3)',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Squad Tasks (${group.activeTasks.length}/3)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF77878F)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (group.canAddMoreTasks)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => onAssignTask(group),
                          icon: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Color(0xFF1CB0F6),
                          ),
                          label: const Text(
                            'Add Task',
                            style: TextStyle(
                              color: Color(0xFF1CB0F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (
                    int taskIdx = 0;
                    taskIdx < group.activeTasks.length;
                    taskIdx++
                  ) ...[
                    Builder(
                      builder: (context) {
                        final task = group.activeTasks[taskIdx];
                        final isCompleted = task.isCompletedBy(currentUid);
                        final myScheduledTime = task.scheduledTimeFor(
                          currentUid,
                        );
                        final isAssigner =
                            task.assignedByUid == currentUid ||
                            group.isCreator(currentUid);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: task.isHabit
                                  ? const Color(
                                      0xFF58CC02,
                                    ).withValues(alpha: 0.5)
                                  : const Color(
                                      0xFF1CB0F6,
                                    ).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFB300,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⚡ +200 EXP',
                                      style: TextStyle(
                                        color: Color(0xFFFFB300),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (task.isHabit) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF58CC02,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '🌱 Habit',
                                        style: TextStyle(
                                          color: Color(0xFF58CC02),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (isAssigner)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Remove Task',
                                      onPressed: () =>
                                          taskMateProvider.removeTask(
                                            group.id,
                                            taskIndex: taskIdx,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                'Uploaded by ${task.uploaderDisplay}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF77878F)
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Members Schedule & Completion Status
                              ...group.members.values.map((member) {
                                final sched = task.memberSchedules[member.uid];
                                final hasDone = sched?.completed ?? false;
                                final hasSched = sched?.scheduledTime != null;
                                final cleanHandle = member.username
                                    .trim()
                                    .replaceAll('@', '');

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: const Color(
                                          0xFF58CC02,
                                        ),
                                        child: Text(
                                          member.displayName.isNotEmpty
                                              ? member.displayName[0]
                                                    .toUpperCase()
                                              : 'M',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            text: member.uid == currentUid
                                                ? 'You'
                                                : member.displayName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white
                                                  : scheme.onSurface,
                                            ),
                                            children: [
                                              if (cleanHandle.isNotEmpty)
                                                TextSpan(
                                                  text: ' (@$cleanHandle)',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 11.5,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF77878F,
                                                          )
                                                        : scheme
                                                              .onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (hasDone)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF58CC02,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Done ✅ (+200 EXP)',
                                            style: TextStyle(
                                              color: Color(0xFF58CC02),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                      else if (hasSched)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1CB0F6,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            DateFormat(
                                              'h:mm a',
                                            ).format(sched!.scheduledTime!),
                                            style: const TextStyle(
                                              color: Color(0xFF1CB0F6),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          'No timer set',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFF77878F)
                                                : scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 14),

                              // Action Buttons for Current User
                              if (isCompleted)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF58CC02,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🎉 Task Complete! (+200 EXP Claimed)',
                                      style: TextStyle(
                                        color: Color(0xFF58CC02),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF37464F)
                                                : scheme.outlineVariant,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                        ),
                                        onPressed: () =>
                                            onPickTime(group, taskIdx),
                                        icon: const Icon(
                                          Icons.schedule_rounded,
                                          size: 16,
                                          color: Color(0xFF1CB0F6),
                                        ),
                                        label: Text(
                                          myScheduledTime != null
                                              ? 'Change Timer'
                                              : 'Set My Timer',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF58CC02,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                        ),
                                        onPressed: () =>
                                            onCompleteTask(group, taskIdx),
                                        child: const Text(
                                          'Complete (+200)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── CLAIM EXP BANNER ──
class _ClaimExpBanner extends StatelessWidget {
  final ExpGift gift;
  final VoidCallback onClaim;

  const _ClaimExpBanner({required this.gift, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF66BB6A).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icon/gift_box_icon.svg',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXP Received from ${gift.fromUsername}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${gift.amount} EXP mindset boost waiting for you',
                  style: const TextStyle(
                    color: Color(0xFFC8E6C9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: onClaim,
            child: const Text(
              'Claim',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PARTNER QUEST CARD ──
class _PartnerQuestCard extends StatelessWidget {
  final PartnerQuest quest;
  final bool isDark;
  final bool canSendReminder;
  final int remindersUsed;
  final VoidCallback onSendReminder;
  final VoidCallback onSendExp;

  const _PartnerQuestCard({
    required this.quest,
    required this.isDark,
    required this.canSendReminder,
    required this.remindersUsed,
    required this.onSendReminder,
    required this.onSendExp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Section title + Time remaining
          Row(
            children: [
              Text(
                'Quest with a Friend',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: isDark
                          ? const Color(0xFF77878F)
                          : scheme.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${quest.hoursRemaining}h left',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Avatars Banner: You + Friend
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF23353E)
                  : scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF1CB0F6),
                  child: Text(
                    'You',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('⚡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF58CC02),
                  backgroundImage: quest.partnerPhotoUrl != null
                      ? NetworkImage(quest.partnerPhotoUrl!)
                      : null,
                  child: quest.partnerPhotoUrl == null
                      ? Text(
                          quest.partnerName.isNotEmpty
                              ? quest.partnerName[0].toUpperCase()
                              : 'F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Goal Title & Progress
          Text(
            quest.goalTitle,
            style: TextStyle(
              color: isDark ? Colors.white : scheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: quest.progressRatio,
              minHeight: 12,
              backgroundColor: isDark
                  ? const Color(0xFF2B3D47)
                  : scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1CB0F6)),
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown (You: 3, Friend: 6)
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFF1CB0F6), size: 10),
              const SizedBox(width: 6),
              Text(
                'You: ${quest.myProgress} done',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, color: Color(0xFF58CC02), size: 10),
              const SizedBox(width: 6),
              Text(
                '${quest.partnerName}: ${quest.partnerProgress} done',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons: Reminder & Gift (50 EXP)
          Row(
            children: [
              // Reminder Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : scheme.onSurface,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF37464F)
                          : scheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: canSendReminder ? onSendReminder : null,
                  icon: const Icon(
                    Icons.waving_hand_rounded,
                    color: Color(0xFF1CB0F6),
                    size: 18,
                  ),
                  label: Text(
                    canSendReminder ? 'Reminder' : 'Limit 3/3',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Gift 50 EXP Button
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : scheme.onSurface,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF37464F)
                          : scheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onSendExp,
                  icon: SvgPicture.asset(
                    'assets/icon/gift_box_icon.svg',
                    width: 18,
                    height: 18,
                  ),
                  label: const Text(
                    'Gift 50 EXP',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── FRIENDS LIST TAB ──
class _FriendsListTab extends StatelessWidget {
  final List<FriendUser> friends;
  final bool isFollowingTab;
  final bool isDark;
  final bool canSendReminder;
  final Function(FriendUser) onSendReminder;
  final Function(FriendUser) onSendExp;
  final Function(FriendUser)? onPairQuest;
  final Function(FriendUser)? onUnfollow;
  final Function(FriendUser)? onFollowBack;

  const _FriendsListTab({
    required this.friends,
    required this.isFollowingTab,
    required this.isDark,
    required this.canSendReminder,
    required this.onSendReminder,
    required this.onSendExp,
    this.onPairQuest,
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
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final friend = friends[i];
        return InkWell(
          onTap: () => context.push('/profile/view', extra: friend),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF58CC02),
                  backgroundImage: friend.photoUrl != null
                      ? NetworkImage(friend.photoUrl!)
                      : null,
                  child: friend.photoUrl == null
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            friend.handle,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF77878F)
                                  : scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          if (friend.streakDays > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '🔥 ${friend.streakDays}',
                              style: const TextStyle(
                                color: Color(0xFFFF9600),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isFollowingTab) ...[
                  friend.isFollowing
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF37464F)
                                  : scheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => onUnfollow?.call(friend),
                          child: const Text(
                            'Following',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1CB0F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => onFollowBack?.call(friend),
                          child: const Text(
                            'Follow Back',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                  const SizedBox(width: 4),
                ],
                // Nudge Reminder Button
                IconButton(
                  icon: const Icon(
                    Icons.waving_hand_rounded,
                    color: Color(0xFF1CB0F6),
                    size: 20,
                  ),
                  tooltip: 'Send Task Reminder',
                  onPressed: canSendReminder
                      ? () => onSendReminder(friend)
                      : null,
                ),
                // Gift 50 EXP Button
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icon/gift_box_icon.svg',
                    width: 20,
                    height: 20,
                  ),
                  tooltip: 'Gift 50 EXP',
                  onPressed: () => onSendExp(friend),
                ),
                // More Actions (Pair / Unfollow)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark
                        ? const Color(0xFF77878F)
                        : scheme.onSurfaceVariant,
                  ),
                  color: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (action) {
                    if (action == 'pair') onPairQuest?.call(friend);
                    if (action == 'unfollow') onUnfollow?.call(friend);
                    if (action == 'follow') onFollowBack?.call(friend);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'pair',
                      child: Text(
                        'Pair for Quest',
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (isFollowingTab || friend.isFollowing)
                      const PopupMenuItem(
                        value: 'unfollow',
                        child: Text(
                          'Unfollow',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'follow',
                        child: Text(
                          'Follow Back',
                          style: TextStyle(color: Color(0xFF1CB0F6)),
                        ),
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

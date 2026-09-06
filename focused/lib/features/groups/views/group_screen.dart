import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../friends/providers/friends_provider.dart';
import '../../friends/tabs/task_mates_tab.dart';
import '../tabs/group_history_tab.dart';
import '../../friends/sheets/friend_notification_hub_sheet.dart';
import '../../friends/sheets/create_squad_sheet.dart';
import '../../friends/sheets/assign_squad_task_sheet.dart';
import '../../friends/widgets/squad_task_actions.dart';
import '../../../core/widgets/profile_streak_xp_bar.dart';

class GroupScreen extends StatefulWidget {
  final int initialTabIndex;
  const GroupScreen({super.key, this.initialTabIndex = 0});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant GroupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final target = widget.initialTabIndex.clamp(0, 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final friendsProvider = context.watch<FriendsProvider>();
    final unclaimedGifts = friendsProvider.unclaimedGifts;

    final unreadCount =
        unclaimedGifts.length +
        friendsProvider.groupNotices.where((n) => n['read'] == false).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 54,
        titleSpacing: 18,
        title: Text(
          'Groups',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          // Squad Notifications & Gifts Hub
          Stack(
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
                        fontFamily: 'Quicksand',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          const ProfileStreakXpBar(showProfile: true, avatarRadius: 20),
          const SizedBox(width: 18),
        ],
      ),
      body: Column(
        children: [
          // 2 Tabs: Squads (collection) & History
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Container(
              height: 50,
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
                  Tab(text: 'Squads'),
                  Tab(text: 'History'),
                ],
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Active Squads
                TaskMatesTab(
                  isDark: isDark,
                  onCreateGroup: () => showCreateGroupDialog(context),
                  onAssignTask: (group) => showAssignTaskSheet(context, group),
                  onPickTime: (group, idx) => SquadTaskActions.pickScheduleTime(
                    context,
                    group,
                    taskIndex: idx,
                  ),
                  onStartTask: (group, idx) => SquadTaskActions.startTask(
                    context,
                    group,
                    taskIndex: idx,
                  ),
                ),

                // Tab 2: Group Task History
                GroupHistoryTab(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNotificationHub(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final friendsProvider = context.read<FriendsProvider>();
    friendsProvider.claimAllExpGifts().then((claimed) {
      if (claimed > 0) {
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/friend_user.dart';
import '../../auth/providers/account_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/task_mate_provider.dart';
import '../../../core/widgets/profile_streak_xp_bar.dart';

import '../tabs/activities_tab.dart';
import '../tabs/friends_list_tab.dart';
import '../widgets/claim_exp_banner.dart';
import '../sheets/friend_notification_hub_sheet.dart';

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
      if (mounted &&
          _tabController.index != widget.initialTabIndex.clamp(0, 2)) {
        _tabController.animateTo(widget.initialTabIndex.clamp(0, 2));
      }
      _checkUnclaimedGiftsPopup();
    });
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final target = widget.initialTabIndex.clamp(0, 2);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 54,
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
          const SizedBox(width: 18),
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

                  // ── TABS: ACTIVITIES (FRONT), FOLLOWING & FOLLOWERS ──
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
                        Tab(text: 'Activities'),
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
            // 1. Activities Tab (FRONT)
            ActivitiesTab(
              isDark: isDark,
              onFindFriends: () => context.push('/friends/add'),
            ),

            // 2. Following Tab (with Search & Follow directly at top)
            _FollowingTab(
              following: following,
              isDark: isDark,
              scheme: scheme,
              friendsProvider: friendsProvider,
              onUnfollow: (f) => _confirmUnfollow(context, f),
            ),

            // 3. Followers Tab
            FriendsListTab(
              friends: followers,
              isFollowingTab: false,
              isDark: isDark,
              canSendReminder: friendsProvider.canSendReminder,
              canSendGift: false,
              onSendReminder: (_) {},
              onFollowBack: (f) => friendsProvider.follow(f),
              onUnfollow: (f) => _confirmUnfollow(context, f),
            ),
          ],
        ),
      ),
    );
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

// ── FOLLOWING TAB WITH TOP INLINE SEARCH BAR & DIRECT FOLLOW ──

class _FollowingTab extends StatefulWidget {
  final List<FriendUser> following;
  final bool isDark;
  final ColorScheme scheme;
  final FriendsProvider friendsProvider;
  final Function(FriendUser) onUnfollow;

  const _FollowingTab({
    required this.following,
    required this.isDark,
    required this.scheme,
    required this.friendsProvider,
    required this.onUnfollow,
  });

  @override
  State<_FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends State<_FollowingTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = widget.friendsProvider;
    final isSearching = friendsProvider.isSearching;
    final searchResults = friendsProvider.searchResults;
    final query = _searchController.text.trim();
    final isQueryActive = query.isNotEmpty;

    return Column(
      children: [
        // ── Top Inline Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            controller: _searchController,
            style: TextStyle(
              color: widget.isDark ? Colors.white : widget.scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search username or name to follow…',
              hintStyle: TextStyle(
                color: widget.isDark
                    ? const Color(0xFF77878F)
                    : widget.scheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 13.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF1CB0F6),
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: widget.isDark
                            ? const Color(0xFF77878F)
                            : widget.scheme.onSurfaceVariant,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        friendsProvider.searchUsers('');
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: widget.scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: widget.scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: widget.scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF1CB0F6),
                  width: 1.8,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onChanged: (text) {
              setState(() {});
              friendsProvider.searchUsers(text);
            },
            onSubmitted: (text) {
              friendsProvider.searchUsersImmediate(text);
            },
          ),
        ),

        // ── Body: Search Results OR Normal Following List ──
        Expanded(
          child: isQueryActive
              ? (isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1CB0F6),
                        ),
                      )
                    : searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('😕', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 10),
                            Text(
                              'No users found for "$query"',
                              style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white
                                    : widget.scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check the spelling or try searching their exact handle',
                              style: TextStyle(
                                color: widget.isDark
                                    ? const Color(0xFF77878F)
                                    : widget.scheme.onSurfaceVariant,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: searchResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final user = searchResults[i];
                          return _SearchUserResultTile(
                            user: user,
                            isDark: widget.isDark,
                            scheme: widget.scheme,
                            onFollow: () => friendsProvider.follow(user),
                            onUnfollow: () => widget.onUnfollow(user),
                          );
                        },
                      ))
              : FriendsListTab(
                  friends: widget.following,
                  isFollowingTab: true,
                  isDark: widget.isDark,
                  canSendReminder: friendsProvider.canSendReminder,
                  canSendReminderTo: (f) =>
                      friendsProvider.canNudgeFriend(f.uid),
                  canSendGift: false,
                  onSendReminder: (f) async {
                    final ok = await friendsProvider.sendReminder(f.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            ok
                                ? '🔔 Reminder sent to ${f.displayName}! (${friendsProvider.remindersSentToday}/5 sent today)'
                                : (friendsProvider.hasNudgedToday(f.uid)
                                      ? 'Already reminded ${f.displayName} today.'
                                      : 'Daily limit of 5 reminders reached.'),
                          ),
                        ),
                      );
                    }
                  },
                  onUnfollow: widget.onUnfollow,
                ),
        ),
      ],
    );
  }
}

class _SearchUserResultTile extends StatelessWidget {
  final FriendUser user;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;

  const _SearchUserResultTile({
    required this.user,
    required this.isDark,
    required this.scheme,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/profile/view', extra: user),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF58CC02),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      _initials(user.displayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                    user.displayName,
                    style: TextStyle(
                      color: isDark ? Colors.white : scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        user.handle,
                        style: const TextStyle(
                          color: Color(0xFF1CB0F6),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      if (user.streakDays > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '🔥 ${user.streakDays}d',
                          style: const TextStyle(
                            color: Color(0xFFFF9600),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (user.isSelf)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF26334D)
                      : const Color(0xFFE8EAF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF1CB0F6),
                  ),
                ),
              )
            else if (user.isFollowing)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF37464F)
                        : scheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onUnfollow,
                child: const Text(
                  'Following',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1CB0F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onFollow,
                child: const Text(
                  'Follow',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

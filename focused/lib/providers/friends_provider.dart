import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/exp_gift.dart';
import '../models/friend_user.dart';
import '../models/partner_quest.dart';
import '../services/friends_service.dart';
import '../services/task_notification_service.dart';
import 'user_profile_provider.dart';
import 'user_stats_provider.dart';

class FriendsProvider extends ChangeNotifier {
  final FriendsService _friendsService;
  final UserProfileProvider _profileProvider;
  final UserStatsProvider _statsProvider;
  final TaskNotificationService? _notificationService;

  FriendsProvider({
    required FriendsService friendsService,
    required UserProfileProvider profileProvider,
    required UserStatsProvider statsProvider,
    TaskNotificationService? notificationService,
  })  : _friendsService = friendsService,
        _profileProvider = profileProvider,
        _statsProvider = statsProvider,
        _notificationService = notificationService;

  String _currentUid = '';
  List<FriendUser> _following = [];
  List<FriendUser> _followers = [];
  List<ExpGift> _unclaimedGifts = [];
  PartnerQuest? _partnerQuest;

  // Search state
  bool _isSearching = false;
  List<FriendUser> _searchResults = [];

  // Daily reminder counter (max 3/day)
  int _remindersSentToday = 0;
  String _lastReminderDate = '';

  StreamSubscription? _followingSub;
  StreamSubscription? _followersSub;
  StreamSubscription? _giftsSub;
  StreamSubscription? _questSub;
  StreamSubscription? _incomingRemindersSub;

  List<FriendUser> get following => _following;
  List<FriendUser> get followers => _followers;
  List<ExpGift> get unclaimedGifts => _unclaimedGifts;
  PartnerQuest? get partnerQuest => _partnerQuest;
  bool get isSearching => _isSearching;
  List<FriendUser> get searchResults => _searchResults;

  static const int maxDailyReminders = 3;
  int get remindersSentToday {
    _checkDailyReset();
    return _remindersSentToday;
  }
  bool get canSendReminder => remindersSentToday < maxDailyReminders;

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _checkDailyReset() {
    if (_lastReminderDate != _todayKey) {
      _remindersSentToday = 0;
      _lastReminderDate = _todayKey;
    }
  }

  /// Initialize listeners for the authenticated user
  void initForUser(String uid, {String? displayName, String? photoUrl}) {
    if (_currentUid == uid && uid.isNotEmpty) return;
    _currentUid = uid;
    _cancelSubs();

    if (uid.isEmpty) {
      _following = [];
      _followers = [];
      _unclaimedGifts = [];
      _partnerQuest = null;
      notifyListeners();
      return;
    }

    // 1. Publish public profile so friends can discover this user
    final profile = _profileProvider.profile;
    _friendsService.syncPublicProfile(
      uid: uid,
      displayName: displayName ?? profile.displayName,
      username: profile.username,
      photoUrl: photoUrl,
      streakDays: _statsProvider.syncedStreakDays,
      xpPoints: _statsProvider.xpPoints,
      totalFocusMinutes: _statsProvider.stats.totalFocusMinutes,
    );

    // 2. Stream Following
    _followingSub = _friendsService.streamFollowing(uid).listen((list) {
      _following = list;
      // If partner quest is null but we have following, provide default active quest
      if (_partnerQuest == null && _following.isNotEmpty) {
        final first = _following.first;
        _partnerQuest = PartnerQuest(
          partnerUid: first.uid,
          partnerName: first.displayName,
          partnerUsername: first.username,
          partnerPhotoUrl: first.photoUrl,
          myProgress: 3,
          partnerProgress: 6,
          totalTarget: 10,
          hoursRemaining: 23,
        );
      }
      notifyListeners();
    });

    // 3. Stream Followers
    _followersSub = _friendsService.streamFollowers(uid).listen((list) {
      _followers = list;
      notifyListeners();
    });

    // 4. Stream Unclaimed EXP Gifts
    _giftsSub = _friendsService.streamUnclaimedExpGifts(uid).listen((gifts) {
      _unclaimedGifts = gifts;
      notifyListeners();
    });

    // 5. Stream Partner Quest
    _questSub = _friendsService.streamPartnerQuest(uid).listen((quest) {
      if (quest != null) {
        _partnerQuest = quest;
        notifyListeners();
      }
    });

    // 6. Listen for incoming reminders (nudges)
    _incomingRemindersSub = _friendsService.listenForIncomingReminders(
      currentUid: uid,
      onReminderReceived: (fromName, message) {
        _notificationService?.showFriendReminderNotification(
          fromName: fromName,
          message: message,
        );
      },
    );
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<void> searchUsers(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _friendsService.searchUsers(
        currentUid: _currentUid,
        query: clean,
      );
    } catch (e) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // FOLLOW / UNFOLLOW
  // ===========================================================================

  Future<void> follow(FriendUser targetUser) async {
    final profile = _profileProvider.profile;
    await _friendsService.followUser(
      currentUid: _currentUid,
      targetUser: targetUser,
      myDisplayName: profile.displayName,
      myUsername: profile.username,
      myStreakDays: _statsProvider.syncedStreakDays,
      myXpPoints: _statsProvider.xpPoints,
    );

    // Update in search results locally
    final index = _searchResults.indexWhere((u) => u.uid == targetUser.uid);
    if (index != -1) {
      _searchResults[index] = _searchResults[index].copyWith(isFollowing: true);
    }
    notifyListeners();
  }

  Future<void> unfollow(String targetUid) async {
    await _friendsService.unfollowUser(
      currentUid: _currentUid,
      targetUid: targetUid,
    );

    final index = _searchResults.indexWhere((u) => u.uid == targetUid);
    if (index != -1) {
      _searchResults[index] = _searchResults[index].copyWith(isFollowing: false);
    }
    notifyListeners();
  }

  // ===========================================================================
  // REMINDERS (NUDGES)
  // ===========================================================================

  Future<bool> sendReminder(String targetUid) async {
    _checkDailyReset();
    if (_remindersSentToday >= maxDailyReminders) return false;

    final profile = _profileProvider.profile;
    await _friendsService.sendFriendReminder(
      currentUid: _currentUid,
      fromName: profile.displayName,
      fromUsername: profile.handle,
      targetUid: targetUid,
    );

    _remindersSentToday++;
    notifyListeners();
    return true;
  }

  // ===========================================================================
  // EXP GIFTING & CLAIMING
  // ===========================================================================

  Future<bool> send50Exp(String targetUid) async {
    if (_statsProvider.xpPoints < 50) return false;

    // Deduct 50 EXP from sender
    final success = await _statsProvider.spendXp(50);
    if (!success) return false;

    final profile = _profileProvider.profile;
    await _friendsService.sendExpGift(
      currentUid: _currentUid,
      fromName: profile.displayName,
      fromUsername: profile.handle,
      targetUid: targetUid,
      amount: 50,
    );

    return true;
  }

  Future<void> claimExp(ExpGift gift) async {
    // Deposit 50 EXP to receiver
    await _statsProvider.addXp(gift.amount);

    // Mark as claimed in Firestore
    await _friendsService.claimExpGift(
      currentUid: _currentUid,
      giftId: gift.id,
    );

    _unclaimedGifts.removeWhere((g) => g.id == gift.id);
    notifyListeners();
  }

  // ===========================================================================
  // PARTNER PAIRING
  // ===========================================================================

  Future<void> pairWithFriend(FriendUser friend) async {
    final quest = PartnerQuest(
      partnerUid: friend.uid,
      partnerName: friend.displayName,
      partnerUsername: friend.username,
      partnerPhotoUrl: friend.photoUrl,
      goalTitle: 'Complete 10 Focus Sessions or Tasks Together',
      totalTarget: 10,
      myProgress: 0,
      partnerProgress: 0,
      hoursRemaining: 24,
    );
    _partnerQuest = quest;
    notifyListeners();
    await _friendsService.setPartnerQuest(currentUid: _currentUid, quest: quest);
  }

  void _cancelSubs() {
    _followingSub?.cancel();
    _followersSub?.cancel();
    _giftsSub?.cancel();
    _questSub?.cancel();
    _incomingRemindersSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}

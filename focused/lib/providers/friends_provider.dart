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
  }) : _friendsService = friendsService,
       _profileProvider = profileProvider,
       _statsProvider = statsProvider,
       _notificationService = notificationService;

  String _currentUid = '';
  String? _currentPhotoUrl;
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

  /// Checks if a username is available (unique)
  Future<bool> checkUsernameAvailability(String username) async {
    return _friendsService.isUsernameAvailable(
      username: username,
      currentUid: _currentUid,
    );
  }

  /// Updates user handle immediately in Firestore and local state
  Future<bool> updateUsername({
    required String oldUsername,
    required String newUsername,
  }) async {
    if (_currentUid.isEmpty) return false;
    final displayName = _profileProvider.profile.displayName;
    final ok = await _friendsService.updateUsername(
      uid: _currentUid,
      oldUsername: oldUsername,
      newUsername: newUsername,
      displayName: displayName,
    );
    if (ok) {
      await _profileProvider.updateProfile(
        displayName: displayName,
        email: _profileProvider.profile.email,
        username: newUsername,
      );
      // Re-sync public profile
      await _friendsService.syncPublicProfile(
        uid: _currentUid,
        displayName: displayName,
        username: newUsername,
        photoUrl: _currentPhotoUrl,
        streakDays: _statsProvider.syncedStreakDays,
        xpPoints: _statsProvider.xpPoints,
        totalFocusMinutes: _statsProvider.stats.totalFocusMinutes,
      );
      notifyListeners();
    }
    return ok;
  }

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
    _currentPhotoUrl = photoUrl;
    _cancelSubs();

    if (uid.isEmpty) {
      _following = [];
      _followers = [];
      _unclaimedGifts = [];
      _partnerQuest = null;
      notifyListeners();
      return;
    }

    final profile = _profileProvider.profile;

    // 1. Ensure user document & handle reservation are initialized in Firestore
    _friendsService.ensureUserDocumentInitialized(
      uid: uid,
      displayName: displayName ?? profile.displayName,
      email: profile.email,
      preferredUsername: profile.username,
      photoUrl: photoUrl,
    );

    // 2. Publish public profile so friends can discover this user
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
      final followingUids = list.map((f) => f.uid).toSet();
      _followers = _followers
          .map((f) => f.copyWith(isFollowing: followingUids.contains(f.uid)))
          .toList();
      notifyListeners();
    });

    // 3. Stream Followers
    _followersSub = _friendsService.streamFollowers(uid).listen((list) {
      final followingUids = _following.map((f) => f.uid).toSet();
      _followers = list
          .map((f) => f.copyWith(isFollowing: followingUids.contains(f.uid)))
          .toList();
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
  Timer? _searchDebounce;
  int _searchSessionId = 0;

  Future<void> searchUsers(String query) async {
    _searchDebounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final currentSession = ++_searchSessionId;
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _friendsService.searchUsers(
          currentUid: _currentUid,
          query: clean,
        );
        if (_searchSessionId == currentSession) {
          _searchResults = results;
        }
      } catch (e) {
        if (_searchSessionId == currentSession) {
          _searchResults = [];
        }
      } finally {
        if (_searchSessionId == currentSession) {
          _isSearching = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> searchUsersImmediate(String query) async {
    _searchDebounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    final currentSession = ++_searchSessionId;
    try {
      final results = await _friendsService.searchUsers(
        currentUid: _currentUid,
        query: clean,
      );
      if (_searchSessionId == currentSession) {
        _searchResults = results;
      }
    } catch (e) {
      if (_searchSessionId == currentSession) {
        _searchResults = [];
      }
    } finally {
      if (_searchSessionId == currentSession) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  // ===========================================================================
  // FOLLOW / UNFOLLOW
  // ===========================================================================
  static const int maxFriends = 200;
  bool get canFollowMore => _following.length < maxFriends;

  Future<bool> follow(FriendUser targetUser) async {
    if (_currentUid.isEmpty) return false;
    if (_following.length >= maxFriends) return false;

    final profile = _profileProvider.profile;
    try {
      await _friendsService.followUser(
        currentUid: _currentUid,
        targetUser: targetUser,
        myDisplayName: profile.displayName,
        myUsername: profile.username,
        myStreakDays: _statsProvider.syncedStreakDays,
        myXpPoints: _statsProvider.xpPoints,
      );

      // Optimistically update local following list
      if (!_following.any((u) => u.uid == targetUser.uid)) {
        _following = [..._following, targetUser.copyWith(isFollowing: true)];
      }

      // Optimistically update followers list isFollowing
      final followerIdx = _followers.indexWhere((u) => u.uid == targetUser.uid);
      if (followerIdx != -1) {
        _followers[followerIdx] = _followers[followerIdx].copyWith(
          isFollowing: true,
        );
      }

      // Update in search results locally
      final index = _searchResults.indexWhere((u) => u.uid == targetUser.uid);
      if (index != -1) {
        _searchResults[index] = _searchResults[index].copyWith(
          isFollowing: true,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error following user: $e');
      return false;
    }
  }

  Future<void> unfollow(String targetUid) async {
    if (_currentUid.isEmpty) return;
    try {
      await _friendsService.unfollowUser(
        currentUid: _currentUid,
        targetUid: targetUid,
      );

      _following = _following.where((u) => u.uid != targetUid).toList();

      final followerIdx = _followers.indexWhere((u) => u.uid == targetUid);
      if (followerIdx != -1) {
        _followers[followerIdx] = _followers[followerIdx].copyWith(
          isFollowing: false,
        );
      }

      final index = _searchResults.indexWhere((u) => u.uid == targetUid);
      if (index != -1) {
        _searchResults[index] = _searchResults[index].copyWith(
          isFollowing: false,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
    }
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
    await _friendsService.setPartnerQuest(
      currentUid: _currentUid,
      quest: quest,
    );
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

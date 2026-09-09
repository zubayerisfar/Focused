import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/gem_gift.dart';
import '../models/friend_user.dart';
import '../models/best_friend.dart';
import '../../../core/services/ad_service.dart';
import '../services/friends_service.dart';
import '../../tasks/services/task_notification_service.dart';
import '../../settings/providers/notification_preferences_provider.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../streak/providers/user_stats_provider.dart';

class FriendsProvider extends ChangeNotifier {
  final FriendsService _friendsService;
  final UserProfileProvider _profileProvider;
  final UserStatsProvider _statsProvider;
  final TaskNotificationService? _notificationService;
  final NotificationPreferencesProvider? _prefsProvider;

  FriendsProvider({
    required FriendsService friendsService,
    required UserProfileProvider profileProvider,
    required UserStatsProvider statsProvider,
    TaskNotificationService? notificationService,
    NotificationPreferencesProvider? prefsProvider,
  }) : _friendsService = friendsService,
       _profileProvider = profileProvider,
       _statsProvider = statsProvider,
       _notificationService = notificationService,
       _prefsProvider = prefsProvider;

  String _currentUid = '';
  String? _currentPhotoUrl;
  List<FriendUser> _following = [];
  List<FriendUser> _followers = [];
  List<BestFriend> _bestFriends = [];
  List<ExpGift> _unclaimedGifts = [];
  List<Map<String, dynamic>> _groupNotices = [];

  // Search state
  bool _isSearching = false;
  List<FriendUser> _searchResults = [];

  // Daily limits (max 5 reminders, max 5 gifts per day)
  int _remindersSentToday = 0;
  int _giftsSentToday = 0;
  final Set<String> _nudgedFriendUidsToday = {};
  final Set<String> _giftedFriendUidsToday = {};
  String _lastResetDate = '';

  StreamSubscription? _followingSub;
  StreamSubscription? _followersSub;
  StreamSubscription? _bestFriendsSub;
  StreamSubscription? _giftsSub;
  StreamSubscription? _incomingRemindersSub;
  StreamSubscription? _groupNoticesSub;
  StreamSubscription? _groupNoticesListSub;
  StreamSubscription? _followerNoticesSub;
  StreamSubscription? _partnerCompletionsSub;

  List<FriendUser> get following => _following;
  List<FriendUser> get followers => _followers;
  List<BestFriend> get bestFriends => _bestFriends;
  List<ExpGift> get unclaimedGifts => _unclaimedGifts;
  List<Map<String, dynamic>> get groupNotices => _groupNotices;
  bool get isSearching => _isSearching;
  List<FriendUser> get searchResults => _searchResults;

  static const int maxDailyReminders = 5;
  static const int maxDailyGifts = 5;

  int get remindersSentToday {
    _checkDailyReset();
    return _remindersSentToday;
  }

  int get giftsSentToday {
    _checkDailyReset();
    return _giftsSentToday;
  }

  bool get canSendReminder => remindersSentToday < maxDailyReminders;
  bool get canSendGift => giftsSentToday < maxDailyGifts;

  /// Checks if the user has already nudged/reminded a specific friend today
  bool hasNudgedToday(String friendUid) {
    _checkDailyReset();
    if (_nudgedFriendUidsToday.contains(friendUid)) return true;
    try {
      final matching = _following.firstWhere((f) => f.uid == friendUid);
      return matching.hasNudgedToday;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the user has already sent a gift to a specific friend today
  bool hasGiftedToday(String friendUid) {
    _checkDailyReset();
    return _giftedFriendUidsToday.contains(friendUid);
  }

  /// Can nudge a specific friend (under daily quota & haven't sent to them today)
  bool canNudgeFriend(String friendUid) {
    return canSendReminder && !hasNudgedToday(friendUid);
  }

  /// Can gift a specific friend (under daily quota & haven't sent to them today)
  bool canGiftFriend(String friendUid) {
    return canSendGift && !hasGiftedToday(friendUid);
  }

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
    if (_lastResetDate != _todayKey) {
      _remindersSentToday = 0;
      _giftsSentToday = 0;
      _nudgedFriendUidsToday.clear();
      _giftedFriendUidsToday.clear();
      _lastResetDate = _todayKey;
    }
  }

  /// Initialize listeners for the authenticated user
  Future<void> initForUser(
    String uid, {
    String? displayName,
    String? photoUrl,
  }) async {
    if (_currentUid == uid && uid.isNotEmpty) return;
    _currentUid = uid;
    _currentPhotoUrl = photoUrl;
    _cancelSubs();

    if (uid.isEmpty) {
      _following = [];
      _followers = [];
      _unclaimedGifts = [];
      notifyListeners();
      return;
    }

    final profile = _profileProvider.profile;

    // 1. Ensure user document & unique handle reservation are initialized in Firestore
    final assignedUsername = await _friendsService
        .ensureUserDocumentInitialized(
          uid: uid,
          displayName: displayName ?? profile.displayName,
          email: profile.email,
          preferredUsername:
              (profile.username.isNotEmpty &&
                  profile.username.toLowerCase() != 'focuseduser' &&
                  profile.username.toLowerCase() != 'focused_user')
              ? profile.username
              : null,
          photoUrl: photoUrl,
        );

    final effectiveUsername = assignedUsername.isNotEmpty
        ? assignedUsername
        : (profile.username.isNotEmpty &&
                  profile.username.toLowerCase() != 'focuseduser'
              ? profile.username
              : UserProfile.defaultUsernameFromEmail(profile.email));

    if (effectiveUsername.isNotEmpty && effectiveUsername != profile.username) {
      await _profileProvider.updateProfile(
        displayName: displayName ?? profile.displayName,
        email: profile.email,
        username: effectiveUsername,
      );
    }

    // 2. Publish public profile so friends can discover this user
    _friendsService.syncPublicProfile(
      uid: uid,
      displayName: displayName ?? profile.displayName,
      username: effectiveUsername,
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

    // 4. Stream Best Friends (up to 5)
    _bestFriendsSub = _friendsService.streamBestFriends(uid).listen((list) {
      _bestFriends = list;
      // Auto-cleanup expired best friends if 30h passed
      for (final bf in list) {
        if (bf.isExpired) {
          removeBestFriend(bf.uid);
        }
      }
      notifyListeners();
    });

    // 5. Stream Unclaimed EXP Gifts
    Set<String>? knownGiftIds;
    _giftsSub = _friendsService.streamUnclaimedExpGifts(uid).listen((gifts) {
      if (knownGiftIds != null) {
        for (final gift in gifts) {
          if (!knownGiftIds!.contains(gift.id)) {
            if (_prefsProvider?.friendNudgesAndGifts ?? true) {
              _notificationService?.showExpGiftNotification(
                fromName: gift.fromName,
                amount: gift.amount,
              );
            }
          }
        }
      }
      knownGiftIds = gifts.map((g) => g.id).toSet();
      _unclaimedGifts = gifts;
      notifyListeners();
    });

    // 6. Listen for incoming reminders (nudges)
    _incomingRemindersSub = _friendsService.listenForIncomingReminders(
      currentUid: uid,
      onReminderReceived: (fromName, message) {
        if (_prefsProvider?.friendNudgesAndGifts ?? true) {
          _notificationService?.showFriendReminderNotification(
            fromName: fromName,
            message: message,
          );
        }
      },
    );

    // 7. Listen for incoming squad creation and task assignment notices
    _groupNoticesSub = _friendsService.listenForIncomingGroupNotices(
      currentUid: uid,
      onGroupNoticeReceived: (groupName, creatorName) {
        // Handled directly by FCM push notifications
      },
      onTaskAssignedReceived: (groupName, assignerName, taskTitle) {
        // Handled directly by FCM push notifications
      },
    );

    // 8. Stream group notices list for history
    _groupNoticesListSub = _friendsService.streamGroupNotices(uid).listen((
      notices,
    ) {
      _groupNotices = notices;
      notifyListeners();
    });

    // 9. Listen for incoming follower notices
    _followerNoticesSub = _friendsService.listenForIncomingFollowerNotices(
      currentUid: uid,
      onFollowerReceived: (followerName, photoUrl) {
        // Handled directly by FCM push notifications
      },
    );

    // 10. Listen for partner task completions
    _partnerCompletionsSub = _friendsService
        .listenForIncomingPartnerCompletions(
          currentUid: uid,
          onCompletionReceived: (friendName, taskTitle) {
            // Handled directly by FCM push notifications
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

    // Optimistically update UI immediately before the network call
    if (!_following.any((u) => u.uid == targetUser.uid)) {
      _following = [..._following, targetUser.copyWith(isFollowing: true)];
    }
    final followerIdx = _followers.indexWhere((u) => u.uid == targetUser.uid);
    if (followerIdx != -1) {
      _followers[followerIdx] = _followers[followerIdx].copyWith(
        isFollowing: true,
      );
    }
    final searchIdx = _searchResults.indexWhere((u) => u.uid == targetUser.uid);
    if (searchIdx != -1) {
      _searchResults[searchIdx] = _searchResults[searchIdx].copyWith(
        isFollowing: true,
      );
    }
    notifyListeners();

    try {
      await _friendsService.followUser(
        currentUid: _currentUid,
        targetUser: targetUser,
        myDisplayName: profile.displayName,
        myUsername: profile.username,
        myStreakDays: _statsProvider.syncedStreakDays,
        myXpPoints: _statsProvider.xpPoints,
      );
      return true;
    } catch (e) {
      debugPrint('Error following user: $e');
      // Revert optimistic update on failure
      _following = _following.where((u) => u.uid != targetUser.uid).toList();
      if (followerIdx != -1) {
        _followers[followerIdx] = _followers[followerIdx].copyWith(
          isFollowing: false,
        );
      }
      if (searchIdx != -1) {
        _searchResults[searchIdx] = _searchResults[searchIdx].copyWith(
          isFollowing: false,
        );
      }
      notifyListeners();
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
      _bestFriends = _bestFriends.where((bf) => bf.uid != targetUid).toList();

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
    if (_remindersSentToday >= maxDailyReminders ||
        _nudgedFriendUidsToday.contains(targetUid)) {
      return false;
    }

    final profile = _profileProvider.profile;
    await _friendsService.sendFriendReminder(
      currentUid: _currentUid,
      fromName: profile.displayName,
      fromUsername: profile.handle,
      targetUid: targetUid,
    );

    _remindersSentToday++;
    _nudgedFriendUidsToday.add(targetUid);
    notifyListeners();
    return true;
  }

  // ===========================================================================
  // EXP GIFTING & CLAIMING
  // ===========================================================================

  Future<bool> send50Exp(String targetUid) async {
    _checkDailyReset();
    if (_giftsSentToday >= maxDailyGifts ||
        _giftedFriendUidsToday.contains(targetUid)) {
      return false;
    }
    if (_statsProvider.xpPoints < 50) return false;

    // Deduct 50 EXP from sender
    final success = await _statsProvider.spendXp(50);
    if (!success) return false;

    final profile = _profileProvider.profile;
    try {
      await _friendsService.sendExpGift(
        currentUid: _currentUid,
        fromName: profile.displayName,
        fromUsername: profile.handle,
        targetUid: targetUid,
        amount: 50,
      );

      _giftsSentToday++;
      _giftedFriendUidsToday.add(targetUid);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending 50 gems gift: $e');
      await _statsProvider.addXp(50);
      return false;
    }
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

  /// Claims all unclaimed EXP gifts at once (used by Notification Hub)
  Future<int> claimAllExpGifts() async {
    if (_unclaimedGifts.isEmpty) return 0;
    int totalClaimed = 0;
    final toClaim = List<ExpGift>.from(_unclaimedGifts);
    for (final gift in toClaim) {
      await claimExp(gift);
      totalClaimed += gift.amount;
    }
    return totalClaimed;
  }

  // ===========================================================================
  // BEST FRIENDS ACTIONS
  // ===========================================================================

  /// Adds a friend from following as a Best Friend (up to 5 slots)
  Future<bool> addBestFriend(FriendUser friend) async {
    if (_currentUid.isEmpty) return false;
    if (_bestFriends.length >= 5) return false;
    if (_bestFriends.any((bf) => bf.uid == friend.uid)) return false;

    final now = DateTime.now().toUtc();
    final optimisticRecord = BestFriend(
      uid: friend.uid,
      displayName: friend.displayName,
      username: friend.username,
      photoUrl: friend.photoUrl,
      streakDays: 1,
      streakStartedAt: now,
      currentCycleStartedAt: now,
      lastInteractedAt: now,
      isRestoredViaAd: false,
    );

    _bestFriends = [..._bestFriends, optimisticRecord];
    notifyListeners();

    try {
      final profile = _profileProvider.profile;
      await _friendsService.addBestFriend(
        currentUid: _currentUid,
        myProfile: profile,
        myPhotoUrl: _currentPhotoUrl,
        friend: friend,
      );
      return true;
    } catch (e) {
      debugPrint('Error adding best friend: $e');
      _bestFriends = _bestFriends.where((bf) => bf.uid != friend.uid).toList();
      notifyListeners();
      return false;
    }
  }

  /// Removes best friend permanently and resets friendship streak forever
  Future<void> removeBestFriend(String friendUid) async {
    if (_currentUid.isEmpty) return;
    try {
      await _friendsService.removeBestFriend(
        currentUid: _currentUid,
        friendUid: friendUid,
      );
      _bestFriends.removeWhere((bf) => bf.uid == friendUid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing best friend: $e');
    }
  }

  /// Nudge best friend: registers interaction and sends nudge
  Future<bool> nudgeBestFriend(BestFriend friend) async {
    if (_currentUid.isEmpty) return false;
    _checkDailyReset();
    if (_remindersSentToday >= maxDailyReminders ||
        _nudgedFriendUidsToday.contains(friend.uid)) {
      return false;
    }

    final profile = _profileProvider.profile;
    await _friendsService.sendFriendReminder(
      currentUid: _currentUid,
      fromName: profile.displayName,
      fromUsername: profile.handle,
      targetUid: friend.uid,
    );

    // Record interaction for streak increment
    await _friendsService.recordBestFriendInteraction(
      currentUid: _currentUid,
      friendUid: friend.uid,
    );

    _remindersSentToday++;
    _nudgedFriendUidsToday.add(friend.uid);
    notifyListeners();
    return true;
  }

  /// Sends 25 EXP gift to Best Friend:
  /// Requires 25 EXP from sender's balance, records interaction
  Future<bool> send25ExpToBestFriend(BestFriend friend) async {
    if (_currentUid.isEmpty) return false;
    _checkDailyReset();
    if (_giftsSentToday >= maxDailyGifts ||
        _giftedFriendUidsToday.contains(friend.uid)) {
      return false;
    }
    if (_statsProvider.xpPoints < 25) return false;

    // Deduct 25 EXP from sender
    final success = await _statsProvider.spendXp(25);
    if (!success) return false;

    final profile = _profileProvider.profile;
    try {
      await _friendsService.sendExpGift(
        currentUid: _currentUid,
        fromName: profile.displayName,
        fromUsername: profile.handle,
        targetUid: friend.uid,
        amount: 25,
      );

      // Record interaction for streak increment
      await _friendsService.recordBestFriendInteraction(
        currentUid: _currentUid,
        friendUid: friend.uid,
      );

      _giftsSentToday++;
      _giftedFriendUidsToday.add(friend.uid);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending 25 gems gift: $e');
      await _statsProvider.addXp(25);
      return false;
    }
  }

  /// Restores at-risk or broken best friend streak using a Rewarded Ad
  Future<bool> restoreBestFriendStreakWithAd(BestFriend friend) async {
    final completer = Completer<bool>();
    AdService.instance.showRewardedAd(
      onUserEarnedReward: (reward) async {
        await _friendsService.restoreBestFriendStreak(
          currentUid: _currentUid,
          friendUid: friend.uid,
        );
        notifyListeners();
        completer.complete(true);
      },
      onAdDismissed: () {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  void _cancelSubs() {
    _followingSub?.cancel();
    _followersSub?.cancel();
    _bestFriendsSub?.cancel();
    _giftsSub?.cancel();
    _incomingRemindersSub?.cancel();
    _groupNoticesSub?.cancel();
    _groupNoticesListSub?.cancel();
    _followerNoticesSub?.cancel();
    _partnerCompletionsSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}

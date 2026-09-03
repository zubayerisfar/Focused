import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/exp_gift.dart';
import '../models/friend_user.dart';
import '../models/partner_quest.dart';

class FriendsService {
  final FirebaseFirestore _firestore;

  FriendsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ===========================================================================
  // PUBLIC PROFILE SYNC
  // ===========================================================================

  /// Publishes current user's profile to Firestore `users/{uid}` so others can find them
  Future<void> syncPublicProfile({
    required String uid,
    required String displayName,
    required String username,
    String? photoUrl,
    required int streakDays,
    required int xpPoints,
    required int totalFocusMinutes,
  }) async {
    if (uid.trim().isEmpty) return;

    final cleanUsername = username.trim().replaceAll('@', '');
    final data = <String, dynamic>{
      'uid': uid,
      'displayName': displayName.trim().isEmpty
          ? 'Focused User'
          : displayName.trim(),
      'displayNameLower':
          (displayName.trim().isEmpty ? 'focused user' : displayName.trim())
              .toLowerCase(),
      'username': cleanUsername,
      'usernameLower': cleanUsername.toLowerCase(),
      'photoUrl': photoUrl,
      'streakDays': streakDays,
      'xpPoints': xpPoints,
      'totalFocusMinutes': totalFocusMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not sync public profile to Firestore: $e');
    }
  }

  /// Checks whether a username is unique across all users
  Future<bool> isUsernameAvailable({
    required String username,
    required String currentUid,
  }) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;

    try {
      final snap = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: clean)
          .limit(2)
          .get();

      for (final doc in snap.docs) {
        if (doc.id != currentUid) {
          return false; // Already taken by another user
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return true; // Fallback to allow in case of offline/transient error
    }
  }

  /// Atomically reserves a username in `usernames/{usernameLower}`
  Future<bool> reserveUsername({
    required String uid,
    required String username,
  }) async {
    final clean = username.trim().toLowerCase().replaceAll('@', '');
    if (clean.length < 3) return false;

    final docRef = _firestore.collection('usernames').doc(clean);
    try {
      return await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (snap.exists && snap.data()?['uid'] != uid) {
          return false; // Taken!
        }
        transaction.set(docRef, {
          'uid': uid,
          'username': clean,
          'reservedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('Could not reserve username: $e');
      return false;
    }
  }

  /// Ensures full user initialization upon registration or sign in
  Future<void> ensureUserDocumentInitialized({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    if (uid.isEmpty) return;

    final userDocRef = _firestore.collection('users').doc(uid);
    try {
      final userSnap = await userDocRef.get();
      if (!userSnap.exists) {
        final defaultUsername = email.isNotEmpty
            ? email
                  .split('@')
                  .first
                  .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
                  .toLowerCase()
            : displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        final cleanUsername = defaultUsername.isEmpty
            ? 'user_${uid.substring(0, 5)}'
            : defaultUsername;

        await _firestore.runTransaction((transaction) async {
          transaction.set(userDocRef, {
            'uid': uid,
            'displayName': displayName.isEmpty ? 'Focused User' : displayName,
            'displayNameLower':
                (displayName.isEmpty ? 'focused user' : displayName)
                    .toLowerCase(),
            'username': cleanUsername,
            'usernameLower': cleanUsername.toLowerCase(),
            'photoUrl': photoUrl,
            'status': 'active',
            'streakDays': 0,
            'xpPoints': 0,
            'totalFocusMinutes': 0,
            'followingCount': 0,
            'followersCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Reserve in usernames collection
          final usernameRef = _firestore
              .collection('usernames')
              .doc(cleanUsername.toLowerCase());
          transaction.set(usernameRef, {
            'uid': uid,
            'reservedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Private profile
          final privateRef = userDocRef.collection('private').doc('profile');
          transaction.set(privateRef, {
            'email': email,
            'nationality': '',
            'birthday': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await userDocRef.update({'updatedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('Could not initialize user document: $e');
    }
  }

  // ===========================================================================
  // SEARCH USERS
  // ===========================================================================

  /// Searches users by username or displayName prefix (case-insensitive)
  Future<List<FriendUser>> searchUsers({
    required String currentUid,
    required String query,
  }) async {
    final cleanQuery = query.trim().toLowerCase().replaceAll('@', '');
    if (cleanQuery.isEmpty) return const [];

    try {
      // 1. Fetch currently followed user IDs for the current user
      final followingSnap = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .get();
      final followingUids = followingSnap.docs.map((d) => d.id).toSet();

      // 2. Search by username prefix
      final usernameQuery = await _firestore
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: cleanQuery)
          .where('usernameLower', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      // 3. Search by displayName prefix
      final displayNameQuery = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: cleanQuery)
          .where('displayNameLower', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      final resultsMap = <String, FriendUser>{};

      for (final doc in [...usernameQuery.docs, ...displayNameQuery.docs]) {
        if (doc.id == currentUid) continue; // Don't return current user
        final data = doc.data();
        final user = FriendUser.fromMap(
          data,
          docId: doc.id,
          isFollowing: followingUids.contains(doc.id),
        );
        resultsMap[doc.id] = user;
      }

      return resultsMap.values.toList();
    } catch (e) {
      debugPrint('Error searching users in Firestore: $e');
      return const [];
    }
  }

  // ===========================================================================
  // FOLLOW / UNFOLLOW
  // ===========================================================================

  Future<void> followUser({
    required String currentUid,
    required FriendUser targetUser,
    required String myDisplayName,
    required String myUsername,
    String? myPhotoUrl,
    int myStreakDays = 0,
    int myXpPoints = 0,
  }) async {
    final cleanMyUsername = myUsername.replaceAll('@', '').trim();
    final batch = _firestore.batch();

    // 1. Add to my following
    final myFollowingRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUser.uid);

    batch.set(myFollowingRef, {
      'uid': targetUser.uid,
      'displayName': targetUser.displayName,
      'username': targetUser.username,
      'photoUrl': targetUser.photoUrl,
      'streakDays': targetUser.streakDays,
      'xpPoints': targetUser.xpPoints,
      'followedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add to target's followers
    final targetFollowerRef = _firestore
        .collection('users')
        .doc(targetUser.uid)
        .collection('followers')
        .doc(currentUid);

    batch.set(targetFollowerRef, {
      'uid': currentUid,
      'displayName': myDisplayName,
      'username': cleanMyUsername,
      'photoUrl': myPhotoUrl,
      'streakDays': myStreakDays,
      'xpPoints': myXpPoints,
      'followedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();

    final myFollowingRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);

    final targetFollowerRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    batch.delete(myFollowingRef);
    batch.delete(targetFollowerRef);

    await batch.commit();
  }

  Stream<List<FriendUser>> streamFollowing(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((d) {
            return FriendUser.fromMap(d.data(), docId: d.id, isFollowing: true);
          }).toList();
        });
  }

  Stream<List<FriendUser>> streamFollowers(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('followers')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((d) {
            return FriendUser.fromMap(d.data(), docId: d.id);
          }).toList();
        });
  }

  // ===========================================================================
  // FRIEND REMINDERS (NUDGES)
  // ===========================================================================

  /// Sends a task nudge to a friend
  Future<void> sendFriendReminder({
    required String currentUid,
    required String fromName,
    required String fromUsername,
    required String targetUid,
  }) async {
    final cleanUsername = fromUsername.replaceAll('@', '').trim();
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('friend_reminders')
        .add({
          'fromUid': currentUid,
          'fromName': fromName,
          'fromUsername': cleanUsername,
          'message': '$fromName is telling you to finish your task today! 🔥',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
  }

  /// Listens for incoming unread reminders to alert the user
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  listenForIncomingReminders({
    required String currentUid,
    required Function(String fromName, String message) onReminderReceived,
  }) {
    if (currentUid.isEmpty) return null;

    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friend_reminders')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            final fromName = data['fromName']?.toString() ?? 'A Friend';
            final message =
                data['message']?.toString() ??
                '$fromName is reminding you to finish your task!';

            onReminderReceived(fromName, message);

            // Mark as read so it doesn't trigger repeatedly
            doc.reference.update({'read': true});
          }
        });
  }

  // ===========================================================================
  // EXP GIFTING & CLAIMING
  // ===========================================================================

  /// Sends a 50 EXP gift to a friend
  Future<void> sendExpGift({
    required String currentUid,
    required String fromName,
    required String fromUsername,
    required String targetUid,
    int amount = 50,
  }) async {
    final cleanUsername = fromUsername.replaceAll('@', '').trim();
    await _firestore
        .collection('users')
        .doc(targetUid)
        .collection('exp_gifts')
        .add({
          'fromUid': currentUid,
          'fromName': fromName,
          'fromUsername': cleanUsername,
          'amount': amount,
          'claimed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Streams unclaimed EXP gifts for the current user
  Stream<List<ExpGift>> streamUnclaimedExpGifts(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('exp_gifts')
        .where('claimed', isEqualTo: false)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => ExpGift.fromMap(d.data(), docId: d.id))
              .toList();
        });
  }

  /// Marks an EXP gift as claimed
  Future<void> claimExpGift({
    required String currentUid,
    required String giftId,
  }) async {
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('exp_gifts')
        .doc(giftId)
        .update({'claimed': true});
  }

  // ===========================================================================
  // PARTNER QUEST
  // ===========================================================================

  Stream<PartnerQuest?> streamPartnerQuest(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('partner_quest')
        .doc('current')
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return PartnerQuest.fromMap(doc.data()!);
        });
  }

  Future<void> setPartnerQuest({
    required String currentUid,
    required PartnerQuest quest,
  }) async {
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('partner_quest')
        .doc('current')
        .set(quest.toMap(), SetOptions(merge: true));
  }
}

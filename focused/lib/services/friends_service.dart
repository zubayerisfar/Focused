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
    String? preferredUsername,
    String? photoUrl,
  }) async {
    if (uid.isEmpty) return;

    final userDocRef = _firestore.collection('users').doc(uid);
    try {
      final userSnap = await userDocRef.get();
      if (!userSnap.exists) {
        final defaultUsername =
            preferredUsername != null && preferredUsername.trim().isNotEmpty
            ? preferredUsername.trim().replaceAll('@', '').toLowerCase()
            : (email.isNotEmpty
                  ? email
                        .split('@')
                        .first
                        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
                        .toLowerCase()
                  : displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase());
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
        // Backfill existing / older accounts so they become searchable immediately
        final data = userSnap.data() ?? {};
        final existingUsername = data['username'] as String?;
        final existingUsernameLower = data['usernameLower'] as String?;
        final existingDisplayName = data['displayName'] as String?;
        final existingDisplayNameLower = data['displayNameLower'] as String?;

        final resolvedUsername =
            (preferredUsername != null && preferredUsername.trim().isNotEmpty)
            ? preferredUsername.trim().replaceAll('@', '').toLowerCase()
            : ((existingUsername != null && existingUsername.isNotEmpty)
                  ? existingUsername.replaceAll('@', '')
                  : (email.isNotEmpty
                        ? email
                              .split('@')
                              .first
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
                              .toLowerCase()
                        : displayName
                              .replaceAll(RegExp(r'\s+'), '')
                              .toLowerCase()));
        final cleanUsername = resolvedUsername.isEmpty
            ? 'user_${uid.substring(0, 5)}'
            : resolvedUsername;

        final resolvedDisplayName = (displayName.isNotEmpty)
            ? displayName
            : ((existingDisplayName != null && existingDisplayName.isNotEmpty)
                  ? existingDisplayName
                  : 'Focused User');

        final updates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (existingUsernameLower == null ||
            existingUsername == null ||
            existingUsername != cleanUsername) {
          updates['username'] = cleanUsername;
          updates['usernameLower'] = cleanUsername.toLowerCase();
          // Also reserve in usernames registry
          try {
            await _firestore
                .collection('usernames')
                .doc(cleanUsername.toLowerCase())
                .set({
                  'uid': uid,
                  'reservedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          } catch (e) {
            debugPrint(
              'Could not register username in usernames collection: $e',
            );
          }
        }

        if (existingDisplayNameLower == null || existingDisplayName == null) {
          updates['displayName'] = resolvedDisplayName;
          updates['displayNameLower'] = resolvedDisplayName.toLowerCase();
        }

        if (photoUrl != null &&
            photoUrl.isNotEmpty &&
            data['photoUrl'] == null) {
          updates['photoUrl'] = photoUrl;
        }

        await userDocRef.set(updates, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Could not initialize user document: $e');
    }
  }

  /// Atomically updates a user's username in Firestore `users/{uid}` and the `usernames/` registry
  Future<bool> updateUsername({
    required String uid,
    required String oldUsername,
    required String newUsername,
    required String displayName,
  }) async {
    final cleanOld = oldUsername.trim().toLowerCase().replaceAll('@', '');
    final cleanNew = newUsername.trim().toLowerCase().replaceAll('@', '');
    if (cleanNew.length < 3) return false;

    final newDocRef = _firestore.collection('usernames').doc(cleanNew);
    final userDocRef = _firestore.collection('users').doc(uid);

    try {
      final success = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final snap = await transaction.get(newDocRef);
        if (snap.exists && snap.data()?['uid'] != uid) {
          return false; // Taken by someone else
        }
        transaction.set(newDocRef, {
          'uid': uid,
          'username': cleanNew,
          'reservedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userDocRef, {
          'username': cleanNew,
          'usernameLower': cleanNew,
          'displayName': displayName.isEmpty ? 'Focused User' : displayName,
          'displayNameLower':
              (displayName.isEmpty ? 'focused user' : displayName)
                  .toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      });

      if (!success) return false;

      // Release old handle reservation if changed
      if (cleanOld.isNotEmpty && cleanOld != cleanNew) {
        try {
          final oldDocRef = _firestore.collection('usernames').doc(cleanOld);
          final oldSnap = await oldDocRef.get();
          if (oldSnap.exists && oldSnap.data()?['uid'] == uid) {
            await oldDocRef.delete();
          }
        } catch (e) {
          debugPrint('Could not delete old username reservation: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating username in Firestore: $e');
      return false;
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
      final followingUids = <String>{};
      if (currentUid.isNotEmpty) {
        try {
          final followingSnap = await _firestore
              .collection('users')
              .doc(currentUid)
              .collection('following')
              .get();
          followingUids.addAll(followingSnap.docs.map((d) => d.id));
        } catch (e) {
          debugPrint('Could not load following for search: $e');
        }
      }

      final resultsMap = <String, FriendUser>{};

      // Helper to add or enrich a found user
      Future<void> addFoundUser({
        required String uid,
        required String username,
        Map<String, dynamic>? preloadedData,
      }) async {
        if (resultsMap.containsKey(uid)) return;

        Map<String, dynamic> data = preloadedData ?? {};
        if (data.isEmpty) {
          try {
            final snap = await _firestore.collection('users').doc(uid).get();
            if (snap.exists && snap.data() != null) {
              data = snap.data()!;
            }
          } catch (_) {}
        }

        final isSelf = currentUid.isNotEmpty && uid == currentUid;
        final dName = (data['displayName'] as String?)?.trim();
        final uName = (data['username'] as String?)?.trim();

        resultsMap[uid] = FriendUser(
          uid: uid,
          displayName: (dName != null && dName.isNotEmpty) ? dName : username,
          username: (uName != null && uName.isNotEmpty) ? uName : username,
          photoUrl: data['photoUrl'] as String?,
          streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
          xpPoints: (data['xpPoints'] as num?)?.toInt() ?? 0,
          isFollowing: followingUids.contains(uid),
          isSelf: isSelf,
        );
      }

      // 1. Direct exact match in /usernames registry
      try {
        final exactSnap = await _firestore
            .collection('usernames')
            .doc(cleanQuery)
            .get();
        if (exactSnap.exists) {
          final targetUid = exactSnap.data()?['uid'] as String?;
          final claimedUsername =
              exactSnap.data()?['username'] as String? ?? exactSnap.id;
          if (targetUid != null && targetUid.isNotEmpty) {
            await addFoundUser(uid: targetUid, username: claimedUsername);
          }
        }
      } catch (e) {
        debugPrint('Direct username match error: $e');
      }

      // 2. Prefix search on /usernames collection directly
      try {
        final usernamesColQuery = await _firestore
            .collection('usernames')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: cleanQuery)
            .where(
              FieldPath.documentId,
              isLessThanOrEqualTo: '$cleanQuery\uf8ff',
            )
            .limit(20)
            .get();

        for (final doc in usernamesColQuery.docs) {
          final targetUid = doc.data()['uid'] as String?;
          final uName = doc.data()['username'] as String? ?? doc.id;
          if (targetUid != null && targetUid.isNotEmpty) {
            await addFoundUser(uid: targetUid, username: uName);
          }
        }
      } catch (e) {
        debugPrint('Usernames prefix search error: $e');
      }

      // 3. Prefix search on /users collection by usernameLower
      try {
        final usernameQuery = await _firestore
            .collection('users')
            .where('usernameLower', isGreaterThanOrEqualTo: cleanQuery)
            .where('usernameLower', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
            .limit(20)
            .get();

        for (final doc in usernameQuery.docs) {
          await addFoundUser(
            uid: doc.id,
            username: doc.data()['username'] as String? ?? cleanQuery,
            preloadedData: doc.data(),
          );
        }
      } catch (e) {
        debugPrint('Users username prefix search error: $e');
      }

      // 4. Prefix search on /users collection by displayNameLower
      try {
        final displayNameQuery = await _firestore
            .collection('users')
            .where('displayNameLower', isGreaterThanOrEqualTo: cleanQuery)
            .where('displayNameLower', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
            .limit(20)
            .get();

        for (final doc in displayNameQuery.docs) {
          await addFoundUser(
            uid: doc.id,
            username: doc.data()['username'] as String? ?? cleanQuery,
            preloadedData: doc.data(),
          );
        }
      } catch (e) {
        debugPrint('Users displayName prefix search error: $e');
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

  /// Listens for incoming group notices to alert user of newly joined squads
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  listenForIncomingGroupNotices({
    required String currentUid,
    required Function(String groupName, String creatorName)
    onGroupNoticeReceived,
  }) {
    if (currentUid.isEmpty) return null;

    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('group_notices')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            final groupName = data['groupName']?.toString() ?? 'Task Squad';
            final creatorName = data['creatorName']?.toString() ?? 'A Friend';

            onGroupNoticeReceived(groupName, creatorName);

            // Mark as read
            doc.reference.update({'read': true});
          }
        });
  }

  /// Streams all group notices for the notification hub
  Stream<List<Map<String, dynamic>>> streamGroupNotices(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('group_notices')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
        );
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

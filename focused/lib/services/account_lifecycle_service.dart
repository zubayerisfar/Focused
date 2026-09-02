import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';

import 'focus_analysis_storage_service.dart';
import 'focus_session_storage_service.dart';
import 'habit_storage_service.dart';
import 'streak_goal_storage_service.dart';
import 'sync_metadata_storage_service.dart';
import 'task_occurrence_completion_storage_service.dart';
import 'task_storage_service.dart';
import 'usage_record_storage_service.dart';
import 'user_cloud_stats_storage_service.dart';
import 'user_profile_storage_service.dart';

enum AccountStatus { active, deactivated, deleted }

class DeactivatedAccountException implements Exception {
  final String message;
  const DeactivatedAccountException([
    this.message =
        'Your account is deactivated. Please contact support.focused@gmail.com',
  ]);

  @override
  String toString() => message;
}

class AccountLifecycleService {
  AccountLifecycleService({
    FirebaseFirestore? firestore,
    required TaskStorageService taskStorage,
    required TaskOccurrenceCompletionStorageService taskCompletionStorage,
    required HabitStorageService habitStorage,
    required FocusSessionStorageService focusSessionStorage,
    required FocusAnalysisStorageService focusAnalysisStorage,
    required UserProfileStorageService userProfileStorage,
    required StreakGoalStorageService streakGoalStorage,
    required SyncMetadataStorageService syncMetadataStorage,
    UserCloudStatsStorageService? userStatsStorage,
    UsageRecordStorageService? usageRecordStorage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _taskStorage = taskStorage,
       _taskCompletionStorage = taskCompletionStorage,
       _habitStorage = habitStorage,
       _focusSessionStorage = focusSessionStorage,
       _focusAnalysisStorage = focusAnalysisStorage,
       _userProfileStorage = userProfileStorage,
       _streakGoalStorage = streakGoalStorage,
       _syncMetadataStorage = syncMetadataStorage,
       _userStatsStorage = userStatsStorage,
       _usageRecordStorage = usageRecordStorage;

  final FirebaseFirestore _firestore;
  final TaskStorageService _taskStorage;
  final TaskOccurrenceCompletionStorageService _taskCompletionStorage;
  final HabitStorageService _habitStorage;
  final FocusSessionStorageService _focusSessionStorage;
  final FocusAnalysisStorageService _focusAnalysisStorage;
  final UserProfileStorageService _userProfileStorage;
  final StreakGoalStorageService _streakGoalStorage;
  final SyncMetadataStorageService _syncMetadataStorage;
  final UserCloudStatsStorageService? _userStatsStorage;
  final UsageRecordStorageService? _usageRecordStorage;

  /// Checks whether an account is active or has been marked deactivated.
  Future<AccountStatus> checkAccountStatus(String uid) async {
    if (uid.trim().isEmpty) return AccountStatus.active;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return AccountStatus.active;

      final data = doc.data();
      final status = data?['status']?.toString().toLowerCase();

      if (status == 'deactivated') {
        return AccountStatus.deactivated;
      }
      if (status == 'deleted') {
        return AccountStatus.deleted;
      }
      return AccountStatus.active;
    } catch (e) {
      debugPrint('Could not check account status for $uid: $e');
      return AccountStatus.active;
    }
  }

  /// Deactivates the user account in Firestore and clears local workspace data.
  Future<void> deactivateAccount({
    required String uid,
    required String reason,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('A non-empty UID is required to deactivate.');
    }

    final cleanReason = reason.trim().isEmpty ? 'Not specified' : reason.trim();

    await _firestore.collection('users').doc(uid).set({
      'status': 'deactivated',
      'deactivatedAt': FieldValue.serverTimestamp(),
      'deactivationReason': cleanReason,
    }, SetOptions(merge: true));

    await clearLocalWorkspaceData();
  }

  /// Permanently deletes all Cloud Firestore data for the user, clears local
  /// workspace data, and deletes the Firebase Auth account.
  Future<void> deleteAccount({
    required String uid,
    required User firebaseUser,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('A non-empty UID is required to delete an account.');
    }

    // 1. Purge all known subcollections in Firestore
    final subcollections = [
      'tasks',
      'taskCompletions',
      'habits',
      'habitCompletions',
      'focusSessions',
      'profile',
      'devices',
      'settings',
    ];

    for (final col in subcollections) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection(col)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint(
          'Error deleting subcollection $col during account deletion: $e',
        );
      }
    }

    // 2. Delete the root user document in Firestore
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting root user doc during account deletion: $e');
    }

    // 3. Clear local Hive data
    await clearLocalWorkspaceData(wipeAllUsage: true);

    // 4. Delete the Firebase Auth User
    await firebaseUser.delete();
  }

  /// Clears all local workspace data (tasks, completions, habits, focus sessions,
  /// profile, streak goals, sync metadata) to prevent data leakage across accounts.
  Future<void> clearLocalWorkspaceData({bool wipeAllUsage = false}) async {
    try {
      await _taskStorage.clearAllTasks();
    } catch (e) {
      debugPrint('Error clearing tasks: $e');
    }

    try {
      await _taskCompletionStorage.clearAll();
    } catch (e) {
      debugPrint('Error clearing task completions: $e');
    }

    try {
      await _habitStorage.clearAll();
    } catch (e) {
      debugPrint('Error clearing habits: $e');
    }

    try {
      await _focusSessionStorage.clearAll();
    } catch (e) {
      debugPrint('Error clearing focus sessions: $e');
    }

    try {
      await _focusAnalysisStorage.clearAll();
    } catch (e) {
      debugPrint('Error clearing focus analyses: $e');
    }

    try {
      await _userProfileStorage.clearProfile();
    } catch (e) {
      debugPrint('Error clearing profile: $e');
    }

    try {
      await _streakGoalStorage.clearGoalDays();
    } catch (e) {
      debugPrint('Error clearing streak goal: $e');
    }

    try {
      await _syncMetadataStorage.clearMetadata();
      await _syncMetadataStorage.clearBoundAccountUid();
    } catch (e) {
      debugPrint('Error clearing sync metadata: $e');
    }

    try {
      await _userStatsStorage?.clearAll();
    } catch (e) {
      debugPrint('Error clearing user stats: $e');
    }

    if (wipeAllUsage && _usageRecordStorage != null) {
      try {
        await _usageRecordStorage.clearAll();
      } catch (e) {
        debugPrint('Error clearing usage records: $e');
      }
    }
  }
}

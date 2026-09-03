import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../models/device_usage_summary.dart';
import '../models/focus_session.dart';
import '../models/habit.dart';
import '../models/habit_progress.dart';
import '../models/task.dart';
import '../models/task_occurrence_completion.dart';
import '../models/user_cloud_stats.dart';
import '../models/user_profile.dart';
import '../providers/theme_provider.dart';
import 'achievement_service.dart';
import 'device_usage_summary_service.dart';
import 'focus_session_storage_service.dart';
import 'habit_storage_service.dart';
import 'productivity_streak_service.dart';
import 'streak_goal_storage_service.dart';
import 'sync_metadata_storage_service.dart';
import 'task_occurrence_completion_storage_service.dart';
import 'task_storage_service.dart';
import 'usage_record_storage_service.dart';
import 'user_cloud_stats_storage_service.dart';
import 'user_profile_storage_service.dart';

enum CloudSyncMode { bidirectional, downloadOnly, uploadOnly }

class CloudSyncResult {
  const CloudSyncResult({
    required this.pushed,
    required this.pulled,
    required this.deleted,
    required this.syncedAt,
  });

  final int pushed;
  final int pulled;
  final int deleted;
  final DateTime syncedAt;
}

class CloudSyncService {
  CloudSyncService({
    FirebaseFirestore? firestore,
    required SyncMetadataStorageService metadataStorage,
    required TaskStorageService taskStorage,
    required TaskOccurrenceCompletionStorageService taskCompletionStorage,
    required HabitStorageService habitStorage,
    required FocusSessionStorageService focusSessionStorage,
    required UserProfileStorageService userProfileStorage,
    required StreakGoalStorageService streakGoalStorage,
    UserCloudStatsStorageService? userStatsStorage,
    UsageRecordStore? usageRecordStorage,
    ThemeProvider? themeProvider,
    DeviceUsageSummaryService? summaryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _metadataStorage = metadataStorage,
       _taskStorage = taskStorage,
       _taskCompletionStorage = taskCompletionStorage,
       _habitStorage = habitStorage,
       _focusSessionStorage = focusSessionStorage,
       _userProfileStorage = userProfileStorage,
       _streakGoalStorage = streakGoalStorage,
       _userStatsStorage = userStatsStorage,
       _usageRecordStorage = usageRecordStorage,
       _themeProvider = themeProvider,
       _summaryService = summaryService ?? const DeviceUsageSummaryService();

  final FirebaseFirestore _firestore;
  final SyncMetadataStorageService _metadataStorage;
  final TaskStorageService _taskStorage;
  final TaskOccurrenceCompletionStorageService _taskCompletionStorage;
  final HabitStorageService _habitStorage;
  final FocusSessionStorageService _focusSessionStorage;
  final UserProfileStorageService _userProfileStorage;
  final StreakGoalStorageService _streakGoalStorage;
  final UserCloudStatsStorageService? _userStatsStorage;
  final UsageRecordStore? _usageRecordStorage;
  final ThemeProvider? _themeProvider;
  final DeviceUsageSummaryService _summaryService;

  Future<CloudSyncResult> sync({
    required String uid,
    required String deviceId,
    String? deviceName,
    CloudSyncMode mode = CloudSyncMode.bidirectional,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('A signed-in Firebase UID is required for sync.');
    }

    final startedAt = DateTime.now().toUtc();
    var pushed = 0;
    var pulled = 0;
    var deleted = 0;

    await _registerDevice(
      uid: uid,
      deviceId: deviceId,
      firstSeenAt: startedAt,
      deviceName: deviceName,
    );

    // Read and merge root user doc `users/{uid}` in Firestore so console edits are immediately applied
    Map<String, dynamic>? rootDocData;
    try {
      final rootDocSnap = await _firestore.collection('users').doc(uid).get();
      rootDocData = rootDocSnap.data();
    } catch (e) {
      debugPrint('Could not read root user doc: $e');
    }

    if (rootDocData != null && _userStatsStorage != null) {
      final remoteStreak = (rootDocData['streakDays'] as num?)?.toInt() ?? 0;
      final remoteLongest = (rootDocData['longestStreak'] as num?)?.toInt() ?? 0;
      final remoteFocusMinutes = (rootDocData['totalFocusMinutes'] as num?)?.toInt() ?? 0;
      final remoteSessions = (rootDocData['completedSessionsCount'] as num?)?.toInt() ?? 0;
      final remoteBadges = (rootDocData['unlockedBadgeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      final localStats = _userStatsStorage!.loadStats();
      final effectiveStreak = math.max(localStats.streakDays, remoteStreak);
      final effectiveLongest = math.max(
        math.max(localStats.longestStreak, remoteLongest),
        effectiveStreak,
      );
      final effectiveFocus = math.max(localStats.totalFocusMinutes, remoteFocusMinutes);
      final effectiveSessions = math.max(localStats.completedSessionsCount, remoteSessions);
      final mergedBadges = <String>{
        ...localStats.unlockedBadgeIds,
        ...remoteBadges,
      };

      if (effectiveStreak != localStats.streakDays ||
          effectiveFocus != localStats.totalFocusMinutes ||
          effectiveLongest != localStats.longestStreak ||
          mergedBadges.length != localStats.unlockedBadgeIds.length) {
        pulled++;
        final updated = UserCloudStats(
          streakDays: effectiveStreak,
          longestStreak: effectiveLongest,
          totalFocusMinutes: effectiveFocus,
          completedSessionsCount: effectiveSessions,
          unlockedBadgeIds: mergedBadges.toList(),
          updatedAt: DateTime.now().toUtc(),
        );
        await _userStatsStorage!.saveStats(updated);
      }

      final remoteName = rootDocData['displayName'] as String?;
      final remoteNationality = rootDocData['nationality'] as String?;
      if ((remoteName != null && remoteName.isNotEmpty) ||
          (remoteNationality != null && remoteNationality.isNotEmpty)) {
        final currentProfile = _userProfileStorage.loadProfile();
        if (currentProfile != null) {
          final updatedProfile = currentProfile.copyWith(
            displayName: remoteName ?? currentProfile.displayName,
            nationality: remoteNationality ?? currentProfile.nationality,
          );
          await _userProfileStorage.saveProfile(updatedProfile);
        }
      }
    }

    Future<void> syncCollection(_SyncCollectionAdapter adapter) async {
      final result = await _syncCollection(
        uid: uid,
        deviceId: deviceId,
        adapter: adapter,
        mode: mode,
      );
      pushed += result.pushed;
      pulled += result.pulled;
      deleted += result.deleted;
    }

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'tasks',
        loadLocal: () => {
          for (final task in _taskStorage.loadTasks()) task.id: task.toMap(),
        },
        applyRemote: (id, payload) =>
            _taskStorage.saveTask(Task.fromMap(payload)),
        deleteLocal: _taskStorage.deleteTask,
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'taskCompletions',
        loadLocal: () => {
          for (final completion in _taskCompletionStorage.loadCompletions())
            completion.storageKey: completion.toMap(),
        },
        applyRemote: (id, payload) => _taskCompletionStorage.saveCompletion(
          TaskOccurrenceCompletion.fromMap(payload),
        ),
        deleteLocal: (id) async {
          final separator = id.indexOf('|');
          if (separator <= 0 || separator == id.length - 1) return;
          final taskId = id.substring(0, separator);
          final date = DateTime.tryParse(id.substring(separator + 1));
          if (date == null) return;
          await _taskCompletionStorage.deleteCompletion(
            taskId: taskId,
            occurrenceDate: date,
          );
        },
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'habits',
        loadLocal: () => {
          for (final habit in _habitStorage.loadHabits())
            habit.id: habit.toMap(),
        },
        applyRemote: (id, payload) =>
            _habitStorage.saveHabit(Habit.fromMap(payload)),
        deleteLocal: _habitStorage.deleteHabit,
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'habitCompletions',
        loadLocal: () => {
          for (final progress in _habitStorage.loadProgress())
            progress.storageKey: progress.toMap(),
        },
        applyRemote: (id, payload) =>
            _habitStorage.saveProgress(HabitProgress.fromMap(payload)),
        deleteLocal: (id) async {
          HabitProgress? match;
          for (final progress in _habitStorage.loadProgress()) {
            if (progress.storageKey == id) {
              match = progress;
              break;
            }
          }
          if (match == null) return;
          await _habitStorage.deleteProgress(match.habitId, match.date);
        },
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'focusSessions',
        loadLocal: () => {
          for (final session in _focusSessionStorage.loadSessions())
            session.id: session.toMap(),
        },
        applyRemote: (id, payload) =>
            _focusSessionStorage.saveSession(FocusSession.fromMap(payload)),
        deleteLocal: _focusSessionStorage.deleteSession,
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'profile',
        loadLocal: () {
          final profile = _userProfileStorage.loadProfile();
          return profile == null
              ? <String, Map<String, dynamic>>{}
              : {'main': profile.toMap()};
        },
        applyRemote: (id, payload) =>
            _userProfileStorage.saveProfile(UserProfile.fromMap(payload)),
        deleteLocal: (id) async {},
      ),
    );

    await syncCollection(
      _SyncCollectionAdapter(
        name: 'settings',
        loadLocal: () {
          final themeProvider = _themeProvider;
          return {
            'main': {
              'schemaVersion': 1,
              'streakGoalDays': _streakGoalStorage.loadGoalDays(),
              if (themeProvider != null)
                'themeMode': themeProvider.themeMode.name,
            },
          };
        },
        applyRemote: (id, payload) async {
          final value = payload['streakGoalDays'];
          if (value is num && value.toInt() > 0) {
            await _streakGoalStorage.saveGoalDays(value.toInt());
          }
          final themeName = payload['themeMode'];
          final themeProvider = _themeProvider;
          if (themeName is String && themeProvider != null) {
            final mode = ThemeMode.values.firstWhere(
              (m) => m.name == themeName,
              orElse: () => ThemeMode.system,
            );
            await themeProvider.setThemeMode(mode);
          }
        },
        deleteLocal: (id) async {},
      ),
    );

    if (_userStatsStorage != null) {
      await syncCollection(
        _SyncCollectionAdapter(
          name: 'stats',
          loadLocal: () {
            final stats = _computeCurrentLocalStats();
            return {'main': stats.toMap()};
          },
          applyRemote: (id, payload) async {
            final statsStore = _userStatsStorage!;
            final remoteStats = UserCloudStats.fromMap(payload);
            final localStats = statsStore.loadStats();
            final mergedBadges = <String>{
              ...localStats.unlockedBadgeIds,
              ...remoteStats.unlockedBadgeIds,
            };
            final effectiveStreak = math.max(
              localStats.streakDays,
              remoteStats.streakDays,
            );
            final effectiveLongest = math.max(
              math.max(localStats.longestStreak, remoteStats.longestStreak),
              effectiveStreak,
            );
            final merged = UserCloudStats(
              streakDays: effectiveStreak,
              longestStreak: effectiveLongest,
              totalFocusMinutes: math.max(
                localStats.totalFocusMinutes,
                remoteStats.totalFocusMinutes,
              ),
              completedSessionsCount: math.max(
                localStats.completedSessionsCount,
                remoteStats.completedSessionsCount,
              ),
              unlockedBadgeIds: mergedBadges.toList(),
              updatedAt: DateTime.now().toUtc(),
            );
            await statsStore.saveStats(merged);
          },
          deleteLocal: (id) async {},
        ),
      );
    }

    final completedAt = DateTime.now().toUtc();
    final profile = _userProfileStorage.loadProfile();
    final currentStats =
        _userStatsStorage?.loadStats() ?? _computeCurrentLocalStats();
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        if (profile?.email != null && profile!.email.isNotEmpty)
          'email': profile.email,
        if (profile?.displayName != null && profile!.displayName.isNotEmpty)
          'displayName': profile.displayName,
        if (profile?.nationality != null && profile!.nationality.isNotEmpty)
          'nationality': profile.nationality,
        'streakDays': currentStats.streakDays,
        'longestStreak': currentStats.longestStreak,
        'totalFocusMinutes': currentStats.totalFocusMinutes,
        'completedSessionsCount': currentStats.completedSessionsCount,
        'unlockedBadgesCount': currentStats.unlockedBadgeIds.length,
        'unlockedBadgeIds': currentStats.unlockedBadgeIds,
        'lastSyncedAt': completedAt.toIso8601String(),
        'lastSyncedDeviceId': deviceId,
        if (deviceName != null) 'lastSyncedDeviceName': deviceName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not update root user document: $e');
    }

    await _registerDevice(
      uid: uid,
      deviceId: deviceId,
      firstSeenAt: startedAt,
      lastSyncAt: completedAt,
      deviceName: deviceName,
    );

    return CloudSyncResult(
      pushed: pushed,
      pulled: pulled,
      deleted: deleted,
      syncedAt: completedAt,
    );
  }

  UserCloudStats _computeCurrentLocalStats() {
    final now = DateTime.now();
    final taskActivity = _taskCompletionStorage.loadCompletions().map(
      (c) => c.occurrenceDate,
    );
    final focusActivity = _focusSessionStorage.loadSessions().map(
      (s) => s.startedAt,
    );
    final habitActivity = _habitStorage
        .loadProgress()
        .where((p) => p.value > 0)
        .map((p) => p.date);

    final allDates = <DateTime>{
      ...taskActivity,
      ...focusActivity,
      ...habitActivity,
    };

    const streakService = ProductivityStreakService();
    final streak = streakService.calculateCurrentStreak(
      now: now,
      activityDates: allDates,
    );
    final longestStreak = streakService.calculateLongestStreak(
      activityDates: allDates,
    );

    final sessions = _focusSessionStorage.loadSessions();
    final totalFocusMinutes = sessions.fold<int>(
      0,
      (totalMinutes, session) =>
          totalMinutes + session.actualFocusDuration.inMinutes,
    );
    final longestSession = sessions.fold<Duration>(
      Duration.zero,
      (maxDuration, session) =>
          session.taskId != null && session.actualFocusDuration > maxDuration
          ? session.actualFocusDuration
          : maxDuration,
    );

    const achievementService = AchievementService();
    final existingStats =
        _userStatsStorage?.loadStats() ?? const UserCloudStats();
    final badges = achievementService.buildBadges(
      longestStreak: math.max(longestStreak, existingStats.longestStreak),
      longestLinkedTaskSession: longestSession,
      totalFocus: Duration(
        minutes: math.max(totalFocusMinutes, existingStats.totalFocusMinutes),
      ),
      unlockedBadgeIds: existingStats.unlockedBadgeIds,
    );

    final unlockedBadgeIds =
        badges.where((b) => b.achieved).map((b) => b.id).toSet()
          ..addAll(existingStats.unlockedBadgeIds);

    return UserCloudStats(
      streakDays: math.max(streak, existingStats.streakDays),
      longestStreak: math.max(
        math.max(longestStreak, existingStats.longestStreak),
        math.max(streak, existingStats.streakDays),
      ),
      totalFocusMinutes: math.max(
        totalFocusMinutes,
        existingStats.totalFocusMinutes,
      ),
      completedSessionsCount: math.max(
        sessions.length,
        existingStats.completedSessionsCount,
      ),
      unlockedBadgeIds: unlockedBadgeIds.toList(),
      updatedAt: DateTime.now().toUtc(),
      xpPoints: existingStats.xpPoints,
      xpAdsWatchedToday: existingStats.xpAdsWatchedToday,
      xpAdsWatchedDate: existingStats.xpAdsWatchedDate,
    );
  }

  Future<_CollectionSyncResult> _syncCollection({
    required String uid,
    required String deviceId,
    required _SyncCollectionAdapter adapter,
    required CloudSyncMode mode,
  }) async {
    final now = DateTime.now().toUtc();
    final localRecords = adapter.loadLocal();
    final localMetadata = _metadataStorage.loadCollection(adapter.name);

    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection(adapter.name);
    final snapshot = await collection.get();
    final remote = <String, _RemoteEnvelope>{};
    for (final doc in snapshot.docs) {
      final parsed = _RemoteEnvelope.tryParse(doc.id, doc.data());
      if (parsed != null) remote[doc.id] = parsed;
    }

    if (mode == CloudSyncMode.downloadOnly) {
      var pulled = 0;
      var deleted = 0;
      for (final entry in remote.entries) {
        final id = entry.key;
        final remoteEnvelope = entry.value;
        if (remoteEnvelope.deletedAt != null) {
          if (localRecords.containsKey(id)) {
            await adapter.deleteLocal(id);
            deleted++;
          }
        } else if (remoteEnvelope.payload != null) {
          await adapter.applyRemote(id, remoteEnvelope.payload!);
          pulled++;
        }
        final metadata = LocalSyncMetadata(
          collection: adapter.name,
          id: id,
          createdAt: remoteEnvelope.createdAt,
          updatedAt: remoteEnvelope.updatedAt,
          deletedAt: remoteEnvelope.deletedAt,
          fingerprint: remoteEnvelope.payload == null
              ? null
              : _fingerprint(remoteEnvelope.payload!),
          originDeviceId: remoteEnvelope.originDeviceId,
        );
        localMetadata[id] = metadata;
        await _metadataStorage.save(metadata);
      }
      return _CollectionSyncResult(pushed: 0, pulled: pulled, deleted: deleted);
    }

    if (mode == CloudSyncMode.uploadOnly) {
      var pushed = 0;
      for (final entry in localRecords.entries) {
        final id = entry.key;
        final payload = entry.value;
        final fingerprint = _fingerprint(payload);
        final meta =
            localMetadata[id] ??
            LocalSyncMetadata(
              collection: adapter.name,
              id: id,
              createdAt: now,
              updatedAt: now,
              fingerprint: fingerprint,
              originDeviceId: deviceId,
            );
        await _pushEnvelope(
          collection: collection,
          metadata: meta,
          payload: payload,
          deviceId: deviceId,
        );
        localMetadata[id] = meta;
        await _metadataStorage.save(meta);
        pushed++;
      }
      return _CollectionSyncResult(pushed: pushed, pulled: 0, deleted: 0);
    }

    for (final entry in localRecords.entries) {
      final id = entry.key;
      final fingerprint = _fingerprint(entry.value);
      final previous = localMetadata[id];
      if (previous == null) {
        if (remote.containsKey(id)) continue;
        final metadata = LocalSyncMetadata(
          collection: adapter.name,
          id: id,
          createdAt: now,
          updatedAt: now,
          fingerprint: fingerprint,
          originDeviceId: deviceId,
        );
        localMetadata[id] = metadata;
        await _metadataStorage.save(metadata);
      } else if (previous.isDeleted || previous.fingerprint != fingerprint) {
        final metadata = previous.copyWith(
          updatedAt: now,
          clearDeletedAt: true,
          fingerprint: fingerprint,
          originDeviceId: deviceId,
        );
        localMetadata[id] = metadata;
        await _metadataStorage.save(metadata);
      }
    }

    for (final entry in localMetadata.entries.toList(growable: false)) {
      if (!entry.value.isDeleted && !localRecords.containsKey(entry.key)) {
        final metadata = entry.value.copyWith(
          updatedAt: now,
          deletedAt: now,
          clearFingerprint: true,
          originDeviceId: deviceId,
        );
        localMetadata[entry.key] = metadata;
        await _metadataStorage.save(metadata);
      }
    }

    final ids = <String>{...localMetadata.keys, ...remote.keys};
    var pushed = 0;
    var pulled = 0;
    var deleted = 0;

    for (final id in ids) {
      var localMeta = localMetadata[id];
      final remoteEnvelope = remote[id];

      if (localMeta == null && remoteEnvelope != null) {
        if (remoteEnvelope.deletedAt != null) {
          if (localRecords.containsKey(id)) {
            await adapter.deleteLocal(id);
            deleted++;
          }
        } else if (remoteEnvelope.payload != null) {
          await adapter.applyRemote(id, remoteEnvelope.payload!);
          pulled++;
        }
        final metadata = LocalSyncMetadata(
          collection: adapter.name,
          id: id,
          createdAt: remoteEnvelope.createdAt,
          updatedAt: remoteEnvelope.updatedAt,
          deletedAt: remoteEnvelope.deletedAt,
          fingerprint: remoteEnvelope.payload == null
              ? null
              : _fingerprint(remoteEnvelope.payload!),
          originDeviceId: remoteEnvelope.originDeviceId,
        );
        localMetadata[id] = metadata;
        await _metadataStorage.save(metadata);
        continue;
      }

      if (localMeta == null) continue;

      if (remoteEnvelope == null) {
        await _pushEnvelope(
          collection: collection,
          metadata: localMeta,
          payload: localMeta.isDeleted
              ? null
              : localRecords[id] ?? adapter.loadLocal()[id],
          deviceId: deviceId,
        );
        pushed++;
        continue;
      }

      if (adapter.name == 'stats') {
        if (remoteEnvelope.payload != null) {
          await adapter.applyRemote(id, remoteEnvelope.payload!);
          pulled++;
        }
        final mergedStats = _computeCurrentLocalStats();
        final mergedFingerprint = _fingerprint(mergedStats.toMap());
        final remoteFingerprint = remoteEnvelope.payload == null
            ? null
            : _fingerprint(remoteEnvelope.payload!);

        if (mergedFingerprint != remoteFingerprint) {
          final updatedMeta = localMeta.copyWith(
            updatedAt: now,
            fingerprint: mergedFingerprint,
            originDeviceId: deviceId,
          );
          localMetadata[id] = updatedMeta;
          await _metadataStorage.save(updatedMeta);
          await _pushEnvelope(
            collection: collection,
            metadata: updatedMeta,
            payload: mergedStats.toMap(),
            deviceId: deviceId,
          );
          pushed++;
        }
        continue;
      }

      final localPayload = localMeta.isDeleted
          ? null
          : localRecords[id] ?? adapter.loadLocal()[id];
      final localFingerprint = localPayload == null
          ? null
          : _fingerprint(localPayload);
      final remotePayload = remoteEnvelope.deletedAt != null
          ? null
          : remoteEnvelope.payload;
      final remoteFingerprint = remotePayload == null
          ? null
          : _fingerprint(remotePayload);

      if (localFingerprint == remoteFingerprint &&
          localMeta.isDeleted == (remoteEnvelope.deletedAt != null)) {
        continue;
      }

      final remoteChangedSinceLastSync =
          remoteFingerprint != localMeta.fingerprint;
      final localChangedSinceLastSync =
          localFingerprint != localMeta.fingerprint;

      if (remoteEnvelope.updatedAt.isAfter(localMeta.updatedAt) ||
          (remoteChangedSinceLastSync && !localChangedSinceLastSync)) {
        if (remoteEnvelope.deletedAt != null) {
          await adapter.deleteLocal(id);
          deleted++;
        } else if (remoteEnvelope.payload != null) {
          await adapter.applyRemote(id, remoteEnvelope.payload!);
          pulled++;
        }

        localMeta = LocalSyncMetadata(
          collection: adapter.name,
          id: id,
          createdAt: remoteEnvelope.createdAt,
          updatedAt: remoteEnvelope.updatedAt,
          deletedAt: remoteEnvelope.deletedAt,
          fingerprint: remoteFingerprint,
          originDeviceId: remoteEnvelope.originDeviceId,
        );
        localMetadata[id] = localMeta;
        await _metadataStorage.save(localMeta);
      } else {
        await _pushEnvelope(
          collection: collection,
          metadata: localMeta,
          payload: localPayload,
          deviceId: deviceId,
        );
        pushed++;
      }
    }

    return _CollectionSyncResult(
      pushed: pushed,
      pulled: pulled,
      deleted: deleted,
    );
  }

  Future<void> _pushEnvelope({
    required CollectionReference<Map<String, dynamic>> collection,
    required LocalSyncMetadata metadata,
    required Map<String, dynamic>? payload,
    required String deviceId,
  }) {
    return collection.doc(metadata.id).set({
      'data': payload,
      'createdAt': Timestamp.fromDate(metadata.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(metadata.updatedAt.toUtc()),
      'deletedAt': metadata.deletedAt == null
          ? null
          : Timestamp.fromDate(metadata.deletedAt!.toUtc()),
      'originDeviceId': deviceId,
    }, SetOptions(merge: true));
  }

  Future<bool> isDeviceRegistered({
    required String uid,
    required String deviceId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .get();
    return doc.exists;
  }

  Future<List<CloudDevice>> loadDevices({required String uid}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .get();
    final devices =
        snapshot.docs
            .map((doc) => CloudDevice.tryParse(doc.id, doc.data()))
            .whereType<CloudDevice>()
            .toList()
          ..sort((a, b) {
            final aTime = a.lastSyncAt ?? a.createdAt;
            final bTime = b.lastSyncAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          });
    return List<CloudDevice>.unmodifiable(devices);
  }

  Future<void> deleteDevice({
    required String uid,
    required String deviceId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .delete();
  }

  Future<void> _registerDevice({
    required String uid,
    required String deviceId,
    required DateTime firstSeenAt,
    DateTime? lastSyncAt,
    String? deviceName,
  }) async {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId);
    final existing = await ref.get();

    DeviceUsageSummary? summary;
    try {
      summary = await _summaryService.generateSummary(
        usageRecordStorage: _usageRecordStorage,
        focusSessionStorage: _focusSessionStorage,
      );
    } catch (e) {
      debugPrint('Could not compute device usage summary: $e');
    }

    await ref.set({
      'deviceId': deviceId,
      'platform': platform,
      'deviceName':
          _cleanDeviceName(deviceName) ?? _friendlyDeviceName(platform),
      if (!existing.exists || existing.data()?['createdAt'] is! Timestamp)
        'createdAt': Timestamp.fromDate(firstSeenAt.toUtc()),
      if (lastSyncAt != null)
        'lastSyncAt': Timestamp.fromDate(lastSyncAt.toUtc()),
      'status': 'active',
      if (summary != null) 'usageSummary': summary.toMap(),
    }, SetOptions(merge: true));
  }

  String? _cleanDeviceName(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean.length <= 80 ? clean : clean.substring(0, 80);
  }

  String _friendlyDeviceName(String platform) {
    switch (platform) {
      case 'android':
        return 'Android device';
      case 'windows':
        return 'Windows PC';
      case 'ios':
        return 'iPhone/iPad';
      case 'macOS':
        return 'Mac';
      default:
        return 'Focused device';
    }
  }
}

class CloudDevice {
  const CloudDevice({
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.createdAt,
    required this.lastSyncAt,
    required this.status,
    this.summary,
  });

  final String deviceId;
  final String platform;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? lastSyncAt;
  final String status;
  final DeviceUsageSummary? summary;

  static CloudDevice? tryParse(String id, Map<String, dynamic> map) {
    final createdRaw = map['createdAt'];
    if (createdRaw is! Timestamp) return null;
    final lastSyncRaw = map['lastSyncAt'];
    final summaryRaw = map['usageSummary'];
    return CloudDevice(
      deviceId: map['deviceId'] is String ? map['deviceId'] as String : id,
      platform: map['platform'] is String
          ? map['platform'] as String
          : 'unknown',
      deviceName: map['deviceName'] is String
          ? map['deviceName'] as String
          : 'Focused device',
      createdAt: createdRaw.toDate().toLocal(),
      lastSyncAt: lastSyncRaw is Timestamp
          ? lastSyncRaw.toDate().toLocal()
          : null,
      status: map['status'] is String ? map['status'] as String : 'active',
      summary: summaryRaw is Map
          ? DeviceUsageSummary.fromMap(summaryRaw)
          : null,
    );
  }
}

class _SyncCollectionAdapter {
  const _SyncCollectionAdapter({
    required this.name,
    required this.loadLocal,
    required this.applyRemote,
    required this.deleteLocal,
  });

  final String name;
  final Map<String, Map<String, dynamic>> Function() loadLocal;
  final Future<void> Function(String id, Map<dynamic, dynamic> payload)
  applyRemote;
  final Future<void> Function(String id) deleteLocal;
}

class _CollectionSyncResult {
  const _CollectionSyncResult({
    required this.pushed,
    required this.pulled,
    required this.deleted,
  });
  final int pushed;
  final int pulled;
  final int deleted;
}

class _RemoteEnvelope {
  const _RemoteEnvelope({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.payload,
    required this.originDeviceId,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Map<dynamic, dynamic>? payload;
  final String? originDeviceId;

  static _RemoteEnvelope? tryParse(String id, Map<String, dynamic> map) {
    final created = map['createdAt'];
    final updated = map['updatedAt'];
    if (created is! Timestamp || updated is! Timestamp) return null;
    final deletedRaw = map['deletedAt'];
    final payloadRaw = map['data'];
    return _RemoteEnvelope(
      id: id,
      createdAt: created.toDate().toUtc(),
      updatedAt: updated.toDate().toUtc(),
      deletedAt: deletedRaw is Timestamp ? deletedRaw.toDate().toUtc() : null,
      payload: payloadRaw is Map
          ? Map<dynamic, dynamic>.from(payloadRaw)
          : null,
      originDeviceId: map['originDeviceId'] is String
          ? map['originDeviceId'] as String
          : null,
    );
  }
}

String _fingerprint(Object? value) {
  final canonical = _canonicalize(value);
  final bytes = utf8.encode(canonical);
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _canonicalize(Object? value) {
  if (value == null) return 'null';
  if (value is bool || value is num) return jsonEncode(value);
  if (value is String) return jsonEncode(value);
  if (value is List) {
    return '[${value.map(_canonicalize).join(',')}]';
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalize(entry.value)}').join(',')}}';
  }
  return jsonEncode(value.toString());
}

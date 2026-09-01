import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/focus_session.dart';
import '../models/habit.dart';
import '../models/habit_progress.dart';
import '../models/task.dart';
import '../models/task_occurrence_completion.dart';
import '../models/user_profile.dart';
import 'focus_session_storage_service.dart';
import 'habit_storage_service.dart';
import 'streak_goal_storage_service.dart';
import 'sync_metadata_storage_service.dart';
import 'task_occurrence_completion_storage_service.dart';
import 'task_storage_service.dart';
import 'user_profile_storage_service.dart';

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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _metadataStorage = metadataStorage,
       _taskStorage = taskStorage,
       _taskCompletionStorage = taskCompletionStorage,
       _habitStorage = habitStorage,
       _focusSessionStorage = focusSessionStorage,
       _userProfileStorage = userProfileStorage,
       _streakGoalStorage = streakGoalStorage;

  final FirebaseFirestore _firestore;
  final SyncMetadataStorageService _metadataStorage;
  final TaskStorageService _taskStorage;
  final TaskOccurrenceCompletionStorageService _taskCompletionStorage;
  final HabitStorageService _habitStorage;
  final FocusSessionStorageService _focusSessionStorage;
  final UserProfileStorageService _userProfileStorage;
  final StreakGoalStorageService _streakGoalStorage;

  Future<CloudSyncResult> sync({
    required String uid,
    required String deviceId,
    String? deviceName,
    String? deviceFingerprint,
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
      deviceFingerprint: deviceFingerprint,
    );

    Future<void> syncCollection(_SyncCollectionAdapter adapter) async {
      final result = await _syncCollection(
        uid: uid,
        deviceId: deviceId,
        adapter: adapter,
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
        loadLocal: () => {
          'main': {
            'schemaVersion': 1,
            'streakGoalDays': _streakGoalStorage.loadGoalDays(),
          },
        },
        applyRemote: (id, payload) async {
          final value = payload['streakGoalDays'];
          if (value is num && value.toInt() > 0) {
            await _streakGoalStorage.saveGoalDays(value.toInt());
          }
        },
        deleteLocal: (id) async {},
      ),
    );

    final completedAt = DateTime.now().toUtc();
    await _registerDevice(
      uid: uid,
      deviceId: deviceId,
      firstSeenAt: startedAt,
      lastSyncAt: completedAt,
      deviceName: deviceName,
      deviceFingerprint: deviceFingerprint,
    );

    return CloudSyncResult(
      pushed: pushed,
      pulled: pulled,
      deleted: deleted,
      syncedAt: completedAt,
    );
  }

  Future<_CollectionSyncResult> _syncCollection({
    required String uid,
    required String deviceId,
    required _SyncCollectionAdapter adapter,
  }) async {
    final now = DateTime.now().toUtc();
    final localRecords = adapter.loadLocal();
    final localMetadata = _metadataStorage.loadCollection(adapter.name);

    // Read the cloud before assigning timestamps to records that have never
    // been synced on this installation. This prevents a freshly-created local
    // default (for example profile/settings) from appearing newer than an
    // existing remote record during new-device restore.
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

    for (final entry in localRecords.entries) {
      final id = entry.key;
      final fingerprint = _fingerprint(entry.value);
      final previous = localMetadata[id];
      if (previous == null) {
        // If the cloud already knows this id and this installation has no
        // sync metadata, treat cloud as authoritative for the first merge.
        // Local-only ids still get a new local timestamp and upload normally.
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
          // A cloud tombstone must also remove an unsynced local default that
          // happens to share this id.
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

      if (remoteEnvelope == null ||
          localMeta.updatedAt.isAfter(remoteEnvelope.updatedAt)) {
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

      if (remoteEnvelope.updatedAt.isAfter(localMeta.updatedAt)) {
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
          fingerprint: remoteEnvelope.payload == null
              ? null
              : _fingerprint(remoteEnvelope.payload!),
          originDeviceId: remoteEnvelope.originDeviceId,
        );
        localMetadata[id] = localMeta;
        await _metadataStorage.save(localMeta);
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

  Future<void> _registerDevice({
    required String uid,
    required String deviceId,
    required DateTime firstSeenAt,
    DateTime? lastSyncAt,
    String? deviceName,
    String? deviceFingerprint,
  }) async {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final devices = _firestore
        .collection('users')
        .doc(uid)
        .collection('devices');

    // Reuse an existing physical device record after app data reset.
    DocumentReference<Map<String, dynamic>> ref = devices.doc(deviceId);
    if (deviceFingerprint != null && deviceFingerprint.trim().isNotEmpty) {
      final matches = await devices
          .where('deviceFingerprint', isEqualTo: deviceFingerprint)
          .limit(1)
          .get();
      if (matches.docs.isNotEmpty) {
        ref = matches.docs.first.reference;
      }
    }

    final existing = await ref.get();
    await ref.set({
      'deviceId': ref.id,
      'deviceFingerprint': deviceFingerprint,
      'platform': platform,
      'deviceName':
          _cleanDeviceName(deviceName) ?? _friendlyDeviceName(platform),
      if (!existing.exists || existing.data()?['createdAt'] is! Timestamp)
        'createdAt': Timestamp.fromDate(firstSeenAt.toUtc()),
      if (lastSyncAt != null)
        'lastSyncAt': Timestamp.fromDate(lastSyncAt.toUtc()),
      'status': 'active',
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
  });

  final String deviceId;
  final String platform;
  final String deviceName;
  final DateTime createdAt;
  final DateTime? lastSyncAt;
  final String status;

  static CloudDevice? tryParse(String id, Map<String, dynamic> map) {
    final createdRaw = map['createdAt'];
    if (createdRaw is! Timestamp) return null;
    final lastSyncRaw = map['lastSyncAt'];
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

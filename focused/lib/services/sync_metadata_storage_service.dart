import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

class LocalSyncMetadata {
  const LocalSyncMetadata({
    required this.collection,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.fingerprint,
    this.deletedAt,
    this.originDeviceId,
  });

  final String collection;
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? fingerprint;
  final String? originDeviceId;

  bool get isDeleted => deletedAt != null;

  LocalSyncMetadata copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? fingerprint,
    bool clearFingerprint = false,
    String? originDeviceId,
  }) {
    return LocalSyncMetadata(
      collection: collection,
      id: id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      fingerprint: clearFingerprint ? null : (fingerprint ?? this.fingerprint),
      originDeviceId: originDeviceId ?? this.originDeviceId,
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'collection': collection,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'fingerprint': fingerprint,
    'originDeviceId': originDeviceId,
  };

  factory LocalSyncMetadata.fromMap(Map<dynamic, dynamic> map) {
    final collection = map['collection'];
    final id = map['id'];
    final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}');
    final updatedAt = DateTime.tryParse('${map['updatedAt'] ?? ''}');
    final deletedRaw = map['deletedAt'];
    final deletedAt = deletedRaw is String && deletedRaw.isNotEmpty
        ? DateTime.tryParse(deletedRaw)
        : null;

    if (collection is! String ||
        collection.isEmpty ||
        id is! String ||
        id.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      throw const FormatException('Invalid local sync metadata.');
    }

    return LocalSyncMetadata(
      collection: collection,
      id: id,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      deletedAt: deletedAt?.toUtc(),
      fingerprint: map['fingerprint'] is String
          ? map['fingerprint'] as String
          : null,
      originDeviceId: map['originDeviceId'] is String
          ? map['originDeviceId'] as String
          : null,
    );
  }
}

class SyncMetadataStorageService {
  static const _metadataBoxName = 'focused_sync_metadata_v1';
  static const _installationBoxName = 'focused_installation_v1';
  static const _deviceIdKey = 'device_id';
  static const _usageTrackingStartedAtKey = 'usage_tracking_started_at';
  static const _boundAccountUidKey = 'bound_account_uid';

  Box<dynamic>? _metadataBox;
  Box<dynamic>? _installationBox;

  Future<void> init() async {
    _metadataBox ??= await Hive.openBox<dynamic>(_metadataBoxName);
    _installationBox ??= await Hive.openBox<dynamic>(_installationBoxName);
  }

  Future<String> getOrCreateDeviceId() async {
    final box = _requireInstallationBox();
    final existing = box.get(_deviceIdKey);
    if (existing is String && existing.trim().isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final values = List<int>.generate(4, (_) => random.nextInt(1 << 32));
    final id =
        'device_${DateTime.now().microsecondsSinceEpoch}_'
        '${values.map((value) => value.toRadixString(16).padLeft(8, '0')).join()}';
    await box.put(_deviceIdKey, id);
    return id;
  }

  Future<DateTime> getOrCreateUsageTrackingStartedAt({
    DateTime? installationStartedAt,
  }) async {
    final box = _requireInstallationBox();
    final installTime = installationStartedAt?.toUtc();
    final raw = box.get(_usageTrackingStartedAtKey);

    if (raw is String) {
      final parsed = DateTime.tryParse(raw)?.toUtc();
      if (parsed != null) {
        // Migration repair: an earlier build created this key at upgrade time,
        // which hid valid UsageStats from the same phone. Android's package
        // firstInstallTime survives app updates but resets after uninstall, so
        // it is the correct boundary for "this installation".
        if (installTime != null && installTime.isBefore(parsed)) {
          await box.put(
            _usageTrackingStartedAtKey,
            installTime.toIso8601String(),
          );
          return installTime;
        }
        return parsed;
      }
    }

    final initial = installTime ?? DateTime.now().toUtc();
    await box.put(_usageTrackingStartedAtKey, initial.toIso8601String());
    return initial;
  }

  String? loadBoundAccountUid() {
    final raw = _requireInstallationBox().get(_boundAccountUidKey);
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> bindAccountUid(String uid) async {
    final clean = uid.trim();
    if (clean.isEmpty) {
      throw ArgumentError('A non-empty Firebase UID is required.');
    }
    final existing = loadBoundAccountUid();
    if (existing != null && existing != clean) {
      throw StateError(
        'This local Focused workspace is already linked to another account. '
        'Sign back into that account before syncing.',
      );
    }
    if (existing == null) {
      await _requireInstallationBox().put(_boundAccountUidKey, clean);
    }
  }

  Map<String, LocalSyncMetadata> loadCollection(String collection) {
    final box = _requireMetadataBox();
    final result = <String, LocalSyncMetadata>{};

    for (final entry in box.toMap().entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !key.startsWith('$collection|') || value is! Map) {
        continue;
      }
      try {
        final metadata = LocalSyncMetadata.fromMap(
          Map<dynamic, dynamic>.from(value),
        );
        result[metadata.id] = metadata;
      } catch (_) {
        // Ignore stale development metadata instead of blocking sync.
      }
    }

    return result;
  }

  Future<void> save(LocalSyncMetadata metadata) {
    return _requireMetadataBox().put(
      '${metadata.collection}|${metadata.id}',
      metadata.toMap(),
    );
  }

  Future<void> clearMetadata() async {
    final box = _metadataBox;
    if (box != null && box.isOpen) {
      await box.clear();
    }
  }

  Future<void> clearBoundAccountUid() async {
    final box = _installationBox;
    if (box != null && box.isOpen) {
      await box.delete(_boundAccountUidKey);
    }
  }

  Box<dynamic> _requireMetadataBox() {
    final box = _metadataBox;
    if (box == null || !box.isOpen) {
      throw StateError(
        'SyncMetadataStorageService.init() must be called first.',
      );
    }
    return box;
  }

  Box<dynamic> _requireInstallationBox() {
    final box = _installationBox;
    if (box == null || !box.isOpen) {
      throw StateError(
        'SyncMetadataStorageService.init() must be called first.',
      );
    }
    return box;
  }
}

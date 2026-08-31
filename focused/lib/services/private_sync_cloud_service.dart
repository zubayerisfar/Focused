import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'private_sync_crypto_service.dart';

class PrivateSyncKeyVersionChangedException
    implements Exception {
  const PrivateSyncKeyVersionChangedException();

  @override
  String toString() =>
      'The Focused private key changed on another device.';
}

class PrivateSyncRemoteChangedException
    implements Exception {
  const PrivateSyncRemoteChangedException();

  @override
  String toString() =>
      'The encrypted cloud state changed on another device.';
}

class PrivateSyncAlreadyConfiguredException
    implements Exception {
  const PrivateSyncAlreadyConfiguredException();

  @override
  String toString() =>
      'Private sync is already configured for this account.';
}

class PrivateSyncCloudConfig {
  const PrivateSyncCloudConfig({
    required this.keyVersion,
    required this.wrappedDataKey,
    required this.keyCheck,
    required this.activeRevisionId,
    required this.snapshotTag,
    required this.updatedAt,
  });

  final int keyVersion;
  final EncryptedEnvelope wrappedDataKey;
  final EncryptedEnvelope keyCheck;
  final String? activeRevisionId;
  final String? snapshotTag;
  final DateTime? updatedAt;
}

class PrivateSyncRevisionUpload {
  const PrivateSyncRevisionUpload({
    required this.revisionId,
    required this.snapshotTag,
  });

  final String revisionId;
  final String snapshotTag;
}

class DownloadedPrivateSyncRevision {
  const DownloadedPrivateSyncRevision({
    required this.revisionId,
    required this.envelope,
    required this.snapshotTag,
    required this.compression,
  });

  final String revisionId;
  final EncryptedEnvelope envelope;
  final String snapshotTag;
  final String compression;
}

class PrivateSyncCloudService {
  PrivateSyncCloudService({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ?? FirebaseFirestore.instance;

  static const int _chunkSize = 320 * 1024;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>>
      _configRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('private_sync')
        .doc('config');
  }

  Future<PrivateSyncCloudConfig?> loadConfig(
    String uid,
  ) async {
    final snapshot =
        await _configRef(uid).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    return _configFromMap(data);
  }

  Future<PrivateSyncRevisionUpload>
      createWorkspace({
    required String uid,
    required int keyVersion,
    required EncryptedEnvelope wrappedDataKey,
    required EncryptedEnvelope keyCheck,
    required EncryptedEnvelope encryptedSnapshot,
    required String snapshotTag,
  }) async {
    final configRef = _configRef(uid);

    final revision = await _uploadRevision(
      uid: uid,
      encryptedSnapshot: encryptedSnapshot,
      snapshotTag: snapshotTag,
    );

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final current =
              await transaction.get(configRef);

          if (current.exists) {
            throw const PrivateSyncAlreadyConfiguredException();
          }

          transaction.set(configRef, {
            'schemaVersion': 1,
            'keyFormat': 'FCS1',
            'keyVersion': keyVersion,
            'kdf': 'HKDF-SHA256',
            'keyWrapCipher': 'AES-256-GCM',
            'dataCipher': 'AES-256-GCM',
            'wrappedDataKey':
                wrappedDataKey.toMap(),
            'keyCheck': keyCheck.toMap(),
            'activeRevisionId':
                revision.revisionId,
            'snapshotTag': snapshotTag,
            'createdAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
        },
      );
    } catch (_) {
      await _deleteRevisionBestEffort(
        uid,
        revision.revisionId,
      );
      rethrow;
    }

    return revision;
  }

  Future<PrivateSyncRevisionUpload>
      replaceActiveRevision({
    required String uid,
    required int expectedKeyVersion,
    required String? expectedActiveRevisionId,
    required EncryptedEnvelope encryptedSnapshot,
    required String snapshotTag,
  }) async {
    final configRef = _configRef(uid);

    final revision = await _uploadRevision(
      uid: uid,
      encryptedSnapshot: encryptedSnapshot,
      snapshotTag: snapshotTag,
    );

    String? oldRevisionId;

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final current =
              await transaction.get(configRef);

          final data = current.data();
          if (!current.exists || data == null) {
            throw StateError(
              'Private sync is not configured.',
            );
          }

          final currentVersion =
              (data['keyVersion'] as num?)?.toInt();

          if (currentVersion !=
              expectedKeyVersion) {
            throw const PrivateSyncKeyVersionChangedException();
          }

          final currentRevision =
              data['activeRevisionId'] as String?;

          if (currentRevision !=
              expectedActiveRevisionId) {
            throw const PrivateSyncRemoteChangedException();
          }

          oldRevisionId = currentRevision;

          transaction.update(configRef, {
            'activeRevisionId':
                revision.revisionId,
            'snapshotTag': snapshotTag,
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
        },
      );
    } catch (_) {
      await _deleteRevisionBestEffort(
        uid,
        revision.revisionId,
      );
      rethrow;
    }

    if (oldRevisionId != null &&
        oldRevisionId != revision.revisionId) {
      await _deleteRevisionBestEffort(
        uid,
        oldRevisionId!,
      );
    }

    return revision;
  }

  Future<void> rotateKey({
    required String uid,
    required int expectedKeyVersion,
    required int newKeyVersion,
    required EncryptedEnvelope wrappedDataKey,
    required EncryptedEnvelope keyCheck,
  }) async {
    final configRef = _configRef(uid);

    await _firestore.runTransaction(
      (transaction) async {
        final current =
            await transaction.get(configRef);
        final data = current.data();

        if (!current.exists || data == null) {
          throw StateError(
            'Private sync is not configured.',
          );
        }

        final cloudVersion =
            (data['keyVersion'] as num?)?.toInt();

        if (cloudVersion != expectedKeyVersion) {
          throw const PrivateSyncKeyVersionChangedException();
        }

        transaction.update(configRef, {
          'keyVersion': newKeyVersion,
          'wrappedDataKey':
              wrappedDataKey.toMap(),
          'keyCheck': keyCheck.toMap(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      },
    );
  }

  Future<DownloadedPrivateSyncRevision?>
      downloadActiveRevision({
    required String uid,
    required String? revisionId,
  }) async {
    if (revisionId == null ||
        revisionId.trim().isEmpty) {
      return null;
    }

    final revisionRef = _configRef(uid)
        .collection('revisions')
        .doc(revisionId);

    final revisionSnapshot =
        await revisionRef.get();

    final data = revisionSnapshot.data();
    if (!revisionSnapshot.exists ||
        data == null) {
      throw StateError(
        'Encrypted cloud revision is missing.',
      );
    }

    final chunkCount =
        (data['chunkCount'] as num?)?.toInt();

    final nonce = data['nonce'];
    final mac = data['mac'];
    final tag = data['snapshotTag'];
    final compression = data['compression'];

    if (chunkCount == null ||
        chunkCount < 1 ||
        nonce is! String ||
        mac is! String ||
        tag is! String ||
        compression is! String) {
      throw const FormatException(
        'Encrypted cloud revision metadata is invalid.',
      );
    }

    final cipherText = <int>[];

    for (var index = 0;
        index < chunkCount;
        index++) {
      final chunkId =
          index.toString().padLeft(6, '0');

      final chunkSnapshot =
          await revisionRef
              .collection('chunks')
              .doc(chunkId)
              .get();

      final chunkData = chunkSnapshot.data();
      final raw =
          chunkData?['data'] as String?;

      if (raw == null) {
        throw StateError(
          'Encrypted cloud revision chunk $chunkId is missing.',
        );
      }

      cipherText.addAll(
        base64Url.decode(raw),
      );
    }

    return DownloadedPrivateSyncRevision(
      revisionId: revisionId,
      snapshotTag: tag,
      compression: compression,
      envelope: EncryptedEnvelope(
        nonce: base64Url.decode(nonce),
        cipherText:
            List<int>.unmodifiable(cipherText),
        mac: base64Url.decode(mac),
      ),
    );
  }

  Future<void> disable(String uid) async {
    final configRef = _configRef(uid);
    final revisions =
        await configRef.collection('revisions').get();

    for (final revision in revisions.docs) {
      await _deleteRevisionBestEffort(
        uid,
        revision.id,
      );
    }

    await configRef.delete();
  }

  Future<PrivateSyncRevisionUpload>
      _uploadRevision({
    required String uid,
    required EncryptedEnvelope encryptedSnapshot,
    required String snapshotTag,
  }) async {
    final revisionRef =
        _configRef(uid)
            .collection('revisions')
            .doc();

    final cipherText =
        encryptedSnapshot.cipherText;

    final chunks = <List<int>>[];
    for (var offset = 0;
        offset < cipherText.length;
        offset += _chunkSize) {
      final end =
          offset + _chunkSize < cipherText.length
              ? offset + _chunkSize
              : cipherText.length;
      chunks.add(
        cipherText.sublist(offset, end),
      );
    }

    if (chunks.isEmpty) {
      chunks.add(const <int>[]);
    }

    // Chunks are written before the revision metadata. A revision only
    // becomes eligible to be activated after every chunk exists.
    for (var index = 0;
        index < chunks.length;
        index += 450) {
      final batch = _firestore.batch();
      final end =
          index + 450 < chunks.length
              ? index + 450
              : chunks.length;

      for (var chunkIndex = index;
          chunkIndex < end;
          chunkIndex++) {
        final chunkId =
            chunkIndex
                .toString()
                .padLeft(6, '0');

        batch.set(
          revisionRef
              .collection('chunks')
              .doc(chunkId),
          {
            'index': chunkIndex,
            'data': base64UrlEncode(
              chunks[chunkIndex],
            ),
          },
        );
      }

      await batch.commit();
    }

    await revisionRef.set({
      'schemaVersion': 1,
      'cipher': 'AES-256-GCM',
      'compression': 'gzip',
      'nonce':
          base64UrlEncode(
            encryptedSnapshot.nonce,
          ),
      'mac':
          base64UrlEncode(
            encryptedSnapshot.mac,
          ),
      'chunkCount': chunks.length,
      'cipherTextLength':
          encryptedSnapshot.cipherText.length,
      'snapshotTag': snapshotTag,
      'createdAt':
          FieldValue.serverTimestamp(),
    });

    return PrivateSyncRevisionUpload(
      revisionId: revisionRef.id,
      snapshotTag: snapshotTag,
    );
  }

  Future<void> _deleteRevisionBestEffort(
    String uid,
    String revisionId,
  ) async {
    try {
      final revisionRef =
          _configRef(uid)
              .collection('revisions')
              .doc(revisionId);

      final chunks =
          await revisionRef
              .collection('chunks')
              .get();

      for (var index = 0;
          index < chunks.docs.length;
          index += 450) {
        final batch = _firestore.batch();
        final end =
            index + 450 < chunks.docs.length
                ? index + 450
                : chunks.docs.length;

        for (var item = index;
            item < end;
            item++) {
          batch.delete(chunks.docs[item].reference);
        }

        await batch.commit();
      }

      await revisionRef.delete();
    } catch (_) {
      // Orphaned encrypted revisions contain ciphertext only and can be
      // cleaned later. They are never referenced by activeRevisionId.
    }
  }

  PrivateSyncCloudConfig _configFromMap(
    Map<String, dynamic> data,
  ) {
    final version =
        (data['keyVersion'] as num?)?.toInt();

    final wrappedRaw = data['wrappedDataKey'];
    final checkRaw = data['keyCheck'];

    if (version == null ||
        version < 1 ||
        wrappedRaw is! Map ||
        checkRaw is! Map) {
      throw const FormatException(
        'Private sync configuration is invalid.',
      );
    }

    return PrivateSyncCloudConfig(
      keyVersion: version,
      wrappedDataKey:
          EncryptedEnvelope.fromMap(
        Map<String, dynamic>.from(wrappedRaw),
      ),
      keyCheck:
          EncryptedEnvelope.fromMap(
        Map<String, dynamic>.from(checkRaw),
      ),
      activeRevisionId:
          data['activeRevisionId'] as String?,
      snapshotTag:
          data['snapshotTag'] as String?,
      updatedAt:
          (data['updatedAt'] as Timestamp?)
              ?.toDate(),
    );
  }
}

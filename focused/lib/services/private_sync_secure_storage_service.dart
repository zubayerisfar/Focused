import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalPrivateSyncKeyBundle {
  const LocalPrivateSyncKeyBundle({
    required this.masterKeyBytes,
    required this.dataKeyBytes,
    required this.keyVersion,
  });

  final List<int> masterKeyBytes;
  final List<int> dataKeyBytes;
  final int keyVersion;
}

class PrivateSyncSecureStorageService {
  PrivateSyncSecureStorageService({
    FlutterSecureStorage? storage,
  }) : _storage =
            storage ??
            FlutterSecureStorage(
              aOptions: const AndroidOptions(
                migrateWithBackup: false,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<LocalPrivateSyncKeyBundle?> read(
    String uid,
  ) async {
    final masterRaw = await _storage.read(
      key: _masterKey(uid),
    );
    final dataRaw = await _storage.read(
      key: _dataKey(uid),
    );
    final versionRaw = await _storage.read(
      key: _versionKey(uid),
    );

    if (masterRaw == null ||
        dataRaw == null ||
        versionRaw == null) {
      return null;
    }

    final version = int.tryParse(versionRaw);
    if (version == null || version < 1) {
      return null;
    }

    try {
      final master = base64Url.decode(masterRaw);
      final data = base64Url.decode(dataRaw);

      if (master.length != 32 || data.length != 32) {
        return null;
      }

      return LocalPrivateSyncKeyBundle(
        masterKeyBytes:
            List<int>.unmodifiable(master),
        dataKeyBytes:
            List<int>.unmodifiable(data),
        keyVersion: version,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String uid,
    required LocalPrivateSyncKeyBundle bundle,
  }) async {
    await _storage.write(
      key: _masterKey(uid),
      value: base64UrlEncode(
        bundle.masterKeyBytes,
      ),
    );
    await _storage.write(
      key: _dataKey(uid),
      value: base64UrlEncode(
        bundle.dataKeyBytes,
      ),
    );
    await _storage.write(
      key: _versionKey(uid),
      value: bundle.keyVersion.toString(),
    );
  }

  Future<void> delete(String uid) async {
    await _storage.delete(key: _masterKey(uid));
    await _storage.delete(key: _dataKey(uid));
    await _storage.delete(key: _versionKey(uid));
  }

  static String _masterKey(String uid) =>
      'focused.privateSync.$uid.master.v1';

  static String _dataKey(String uid) =>
      'focused.privateSync.$uid.data.v1';

  static String _versionKey(String uid) =>
      'focused.privateSync.$uid.version.v1';
}

import 'package:hive_ce/hive_ce.dart';

import '../models/app_metadata.dart';

abstract class AppMetadataStore {
  Future<Map<String, AppMetadata>> loadAll();

  Future<void> saveAll(Iterable<AppMetadata> metadata);

  Future<void> delete(String packageName);
}

class AppMetadataStorageService implements AppMetadataStore {
  static const String boxName = 'focused_app_metadata_v1';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  Box<dynamic> get _readyBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'AppMetadataStorageService.init() must be called before use.',
      );
    }
    return box;
  }

  @override
  Future<Map<String, AppMetadata>> loadAll() async {
    final result = <String, AppMetadata>{};

    for (final key in _readyBox.keys) {
      final raw = _readyBox.get(key);
      if (raw is! Map) {
        continue;
      }

      try {
        final metadata = AppMetadata.fromStorageMap(raw);
        result[metadata.packageName] = metadata;
      } catch (_) {
        // Corrupt cache entries are ignored. App metadata is recoverable from
        // Android and must never block Focused from starting.
      }
    }

    return Map<String, AppMetadata>.unmodifiable(result);
  }

  @override
  Future<void> saveAll(Iterable<AppMetadata> metadata) async {
    final values = <String, Map<String, dynamic>>{};

    for (final item in metadata) {
      values[item.packageName] = item.toStorageMap();
    }

    if (values.isEmpty) {
      return;
    }

    await _readyBox.putAll(values);
  }

  @override
  Future<void> delete(String packageName) async {
    await _readyBox.delete(packageName);
  }
}

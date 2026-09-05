import 'package:hive_ce/hive_ce.dart';

import '../models/app_limit.dart';

abstract class AppLimitStore {
  Future<void> init();
  List<AppLimit> loadLimits();
  Future<void> saveLimit(AppLimit limit);
  Future<void> deleteLimit(String packageId);
  Future<void> clearAll();
}

class AppLimitStorageService implements AppLimitStore {
  static const String _boxName = 'focused_app_limits_v1';

  Box<dynamic>? _box;

  bool get isInitialized => _box != null && _box!.isOpen;

  @override
  Future<void> init() async {
    if (isInitialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> _requireBox() {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('AppLimitStorageService must be initialized first.');
    }
    return box;
  }

  @override
  List<AppLimit> loadLimits() {
    final box = _requireBox();
    final limits = <AppLimit>[];
    for (final value in box.values) {
      if (value is! Map) continue;
      try {
        limits.add(AppLimit.fromMap(Map<dynamic, dynamic>.from(value)));
      } catch (_) {
        // Skip malformed records
      }
    }
    return List.unmodifiable(limits);
  }

  @override
  Future<void> saveLimit(AppLimit limit) async {
    final box = _requireBox();
    await box.put(limit.packageId, limit.toMap());
  }

  @override
  Future<void> deleteLimit(String packageId) async {
    final box = _requireBox();
    await box.delete(packageId);
  }

  @override
  Future<void> clearAll() async {
    final box = _box;
    if (box != null && box.isOpen) {
      await box.clear();
    }
  }
}

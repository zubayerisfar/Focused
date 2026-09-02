import 'package:hive_ce/hive_ce.dart';

import '../models/user_cloud_stats.dart';

class UserCloudStatsStorageService {
  static const String _boxName = 'focused_user_cloud_stats_v1';
  static const String _statsKey = 'main';

  Box<dynamic>? _box;

  bool get isInitialized => _box != null && _box!.isOpen;

  Future<void> init() async {
    if (isInitialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> _requireBox() {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError(
        'UserCloudStatsStorageService must be initialized first.',
      );
    }
    return box;
  }

  UserCloudStats loadStats() {
    final box = _requireBox();
    final data = box.get(_statsKey);
    if (data is! Map) {
      return const UserCloudStats();
    }
    try {
      return UserCloudStats.fromMap(Map<dynamic, dynamic>.from(data));
    } catch (_) {
      return const UserCloudStats();
    }
  }

  Future<void> saveStats(UserCloudStats stats) async {
    final box = _requireBox();
    await box.put(_statsKey, stats.toMap());
  }

  Future<void> clearAll() async {
    final box = _box;
    if (box != null && box.isOpen) {
      await box.clear();
    }
  }
}

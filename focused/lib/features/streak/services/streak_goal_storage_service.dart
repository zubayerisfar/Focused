import 'package:hive_ce/hive_ce.dart';

class StreakGoalStorageService {
  static const _boxName = 'focused_streak_preferences';
  static const _goalKey = 'goal_days';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  int loadGoalDays() {
    final value = _box?.get(_goalKey);
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    return 30;
  }

  Future<void> saveGoalDays(int days) async {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Streak goal must be positive.');
    }
    final box = _box;
    if (box == null) {
      throw StateError('StreakGoalStorageService.init() must be called first.');
    }
    await box.put(_goalKey, days);
  }

  Future<void> clearGoalDays() async {
    final box = _box;
    if (box != null && box.isOpen) {
      await box.clear();
    }
  }
}

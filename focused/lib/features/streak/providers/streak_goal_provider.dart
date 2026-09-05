import 'package:flutter/foundation.dart';

import '../services/streak_goal_storage_service.dart';

class StreakGoalProvider extends ChangeNotifier {
  StreakGoalProvider({required StreakGoalStorageService storageService})
      : _storageService = storageService;

  static const allowedGoals = <int>[7, 30, 60, 120, 180, 300];

  final StreakGoalStorageService _storageService;
  int _goalDays = 30;

  int get goalDays => _goalDays;

  Future<void> load() async {
    final stored = _storageService.loadGoalDays();
    _goalDays = allowedGoals.contains(stored) ? stored : 30;
    notifyListeners();
  }

  Future<void> setGoalDays(int days) async {
    if (!allowedGoals.contains(days)) {
      throw ArgumentError.value(days, 'days', 'Unsupported streak goal.');
    }
    if (_goalDays == days) return;
    _goalDays = days;
    notifyListeners();
    await _storageService.saveGoalDays(days);
  }
}

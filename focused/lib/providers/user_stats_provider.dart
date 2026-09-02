import 'package:flutter/foundation.dart';

import '../models/user_cloud_stats.dart';
import '../services/user_cloud_stats_storage_service.dart';

class UserStatsProvider extends ChangeNotifier {
  final UserCloudStatsStorageService _storageService;
  UserCloudStats _stats = const UserCloudStats();

  UserStatsProvider({required UserCloudStatsStorageService storageService})
    : _storageService = storageService;

  UserCloudStats get stats => _stats;
  int get syncedStreakDays => _stats.streakDays;
  int get syncedLongestStreak => _stats.longestStreak;
  Duration get syncedFocusDuration => _stats.totalFocusDuration;
  List<String> get unlockedBadgeIds => _stats.unlockedBadgeIds;

  Future<void> load() async {
    _stats = _storageService.loadStats();
    notifyListeners();
  }

  Future<void> updateStats(UserCloudStats updated) async {
    _stats = updated;
    await _storageService.saveStats(updated);
    notifyListeners();
  }
}

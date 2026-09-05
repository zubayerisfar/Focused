import 'package:flutter/foundation.dart';

import '../../profile/models/user_cloud_stats.dart';
import '../../profile/services/user_cloud_stats_storage_service.dart';

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

  // ──────────────────────────────────────
  // XP System
  // ──────────────────────────────────────

  static const int xpPerRewardedAd = 100;
  static const int xpPerXpPageAd = 500;
  static const int xpAdsPerDay = 2;
  static const int xpStreakRestoreCost = 2000;

  int get xpPoints => _stats.xpPoints;

  /// Today's date as yyyy-MM-dd string
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// How many XP-page ads have been watched today (resets at midnight)
  int get xpAdsWatchedToday {
    if (_stats.xpAdsWatchedDate != _todayKey) return 0;
    return _stats.xpAdsWatchedToday;
  }

  bool get canWatchXpAdToday => xpAdsWatchedToday < xpAdsPerDay;

  Future<void> load() async {
    _stats = _storageService.loadStats();
    notifyListeners();
  }

  Future<void> updateStats(UserCloudStats updated) async {
    _stats = updated;
    await _storageService.saveStats(updated);
    notifyListeners();
  }

  /// Add XP (e.g., from watching a rewarded ad)
  Future<void> addXp(int amount) async {
    final updated = _stats.copyWith(xpPoints: _stats.xpPoints + amount);
    await updateStats(updated);
  }

  /// Spend XP — returns true if successful (enough balance)
  Future<bool> spendXp(int amount) async {
    if (_stats.xpPoints < amount) return false;
    final updated = _stats.copyWith(xpPoints: _stats.xpPoints - amount);
    await updateStats(updated);
    return true;
  }

  /// Record a watched XP-page ad — increments counter for today
  Future<void> recordXpAdWatched() async {
    final today = _todayKey;
    final currentCount = ((_stats.xpAdsWatchedDate == today)
        ? _stats.xpAdsWatchedToday
        : 0);

    final updated = _stats.copyWith(
      xpAdsWatchedToday: currentCount + 1,
      xpAdsWatchedDate: today,
      // Also grant XP
      xpPoints: _stats.xpPoints + xpPerXpPageAd,
    );
    await updateStats(updated);
  }

  /// Restore streak using XP — returns true if successful
  Future<bool> restoreStreakWithXp() async {
    if (_stats.xpPoints < xpStreakRestoreCost) return false;
    final updated = _stats.copyWith(
      xpPoints: _stats.xpPoints - xpStreakRestoreCost,
    );
    await updateStats(updated);
    return true;
  }
}

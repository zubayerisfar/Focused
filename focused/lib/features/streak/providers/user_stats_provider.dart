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
  static const Duration xpAdsCooldownDuration = Duration(hours: 6);

  int get xpPoints => _stats.xpPoints;

  DateTime? get xpAdsCooldownUntil => _stats.xpAdsCooldownUntil;

  /// Whether user is currently in the 6-hour cooldown block
  bool get isXpAdInCooldown {
    final until = _stats.xpAdsCooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Remaining duration in cooldown
  Duration get xpAdRemainingCooldown {
    final until = _stats.xpAdsCooldownUntil;
    if (until == null) return Duration.zero;
    final diff = until.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// How many XP-page ads have been watched in the current batch (resets after cooldown or if expired)
  int get xpAdsWatchedToday {
    // If cooldown was active and has now passed, the batch has expired
    final until = _stats.xpAdsCooldownUntil;
    if (until != null && DateTime.now().isAfter(until)) {
      return 0;
    }
    return _stats.xpAdsWatchedToday;
  }

  /// User can watch an ad if not currently in cooldown and hasn't watched 2 ads in current batch
  bool get canWatchXpAdToday {
    if (isXpAdInCooldown) return false;
    return xpAdsWatchedToday < xpAdsPerDay;
  }

  Future<void> load() async {
    _stats = _storageService.loadStats();
    // Auto-clean expired cooldown if any
    final until = _stats.xpAdsCooldownUntil;
    if (until != null && DateTime.now().isAfter(until)) {
      final updated = _stats.copyWith(
        xpAdsWatchedToday: 0,
        clearCooldown: true,
      );
      await updateStats(updated);
      return;
    }
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

  /// Record a watched XP-page ad — increments count, and triggers 6-hour block if 2 ads reached
  Future<void> recordXpAdWatched() async {
    // Check if previous cooldown expired
    final until = _stats.xpAdsCooldownUntil;
    int currentCount = _stats.xpAdsWatchedToday;
    if (until != null && DateTime.now().isAfter(until)) {
      currentCount = 0;
    }

    final newCount = currentCount + 1;
    final triggersCooldown = newCount >= xpAdsPerDay;
    final cooldownUntil = triggersCooldown
        ? DateTime.now().add(xpAdsCooldownDuration)
        : null;

    final updated = _stats.copyWith(
      xpAdsWatchedToday: triggersCooldown ? 0 : newCount,
      xpAdsCooldownUntil: cooldownUntil,
      clearCooldown: !triggersCooldown,
      // Grant XP
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

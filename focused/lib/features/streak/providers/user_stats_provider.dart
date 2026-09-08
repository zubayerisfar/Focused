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
  // Gem / XP System
  // ──────────────────────────────────────

  static const int gemsPerRewardedAd = 100;
  static const int gemsPerXpPageAd = 100;
  static const int xpAdsPerDay = 2;
  static const int gemStreakRestoreCost = 500;
  static const int gemTaskReward = 20;
  static const int gemHabitReward = 10;
  static const int gemReminderReward = 10;
  static const int gemSquadTaskReward = 50;
  static const int gemSquadTaskDoubleReward = 100;
  static const Duration xpAdsCooldownDuration = Duration(hours: 6);

  // Backward-compat aliases
  static const int xpPerRewardedAd = gemsPerRewardedAd;
  static const int xpPerXpPageAd = gemsPerXpPageAd;
  static const int xpStreakRestoreCost = gemStreakRestoreCost;

  int get gems => _stats.xpPoints;
  int get xpPoints => _stats.xpPoints;

  DateTime? get xpAdsCooldownUntil => _stats.xpAdsCooldownUntil;

  /// Restored calendar dates (yyyy-MM-dd)
  List<String> get restoredStreakDates => _stats.restoredStreakDates;

  Set<DateTime> get parsedRestoredStreakDates {
    return _stats.restoredStreakDates
        .map((str) => DateTime.tryParse(str))
        .whereType<DateTime>()
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet();
  }

  // ──────────────────────────────────────
  // QA Testing: Streak In Danger Simulation
  // ──────────────────────────────────────
  bool _debugSimulateStreakInDanger = false;
  bool get debugSimulateStreakInDanger => _debugSimulateStreakInDanger;

  void setDebugSimulateStreakInDanger(bool value) {
    _debugSimulateStreakInDanger = value;
    notifyListeners();
  }

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

  /// How many Gem/XP-page ads have been watched in the current batch (resets after cooldown or if expired)
  int get xpAdsWatchedToday {
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

  /// Add Gems
  Future<void> addGems(int amount) async {
    final updated = _stats.copyWith(xpPoints: _stats.xpPoints + amount);
    await updateStats(updated);
  }

  /// Spend Gems — returns true if successful (enough balance)
  Future<bool> spendGems(int amount) async {
    if (_stats.xpPoints < amount) return false;
    final updated = _stats.copyWith(xpPoints: _stats.xpPoints - amount);
    await updateStats(updated);
    return true;
  }

  /// Add XP (alias for gems)
  Future<void> addXp(int amount) => addGems(amount);

  /// Spend XP (alias for gems)
  Future<bool> spendXp(int amount) => spendGems(amount);

  /// Record a watched Gem-page ad — increments count, and triggers 6-hour block if 2 ads reached
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
      // Grant Gems
      xpPoints: _stats.xpPoints + gemsPerXpPageAd,
    );
    await updateStats(updated);
  }

  /// Restore streak using Rewarded Ad — repairs the missed day
  Future<bool> restoreStreakWithAd(DateTime missedDate) async {
    final dateStr = _formatDateKey(missedDate);
    final restored = List<String>.from(_stats.restoredStreakDates);
    if (!restored.contains(dateStr)) {
      restored.add(dateStr);
    }
    _debugSimulateStreakInDanger = false;
    final updated = _stats.copyWith(restoredStreakDates: restored);
    await updateStats(updated);
    return true;
  }

  /// Restore streak using 500 Gems — repairs the missed day
  Future<bool> restoreStreakWithGems(DateTime missedDate) async {
    if (_stats.xpPoints < gemStreakRestoreCost) return false;
    final dateStr = _formatDateKey(missedDate);
    final restored = List<String>.from(_stats.restoredStreakDates);
    if (!restored.contains(dateStr)) {
      restored.add(dateStr);
    }
    _debugSimulateStreakInDanger = false;
    final updated = _stats.copyWith(
      xpPoints: _stats.xpPoints - gemStreakRestoreCost,
      restoredStreakDates: restored,
    );
    await updateStats(updated);
    return true;
  }

  /// Restore streak using XP (legacy method)
  Future<bool> restoreStreakWithXp([DateTime? missedDate]) async {
    final targetDate =
        missedDate ?? DateTime.now().subtract(const Duration(days: 1));
    return restoreStreakWithGems(targetDate);
  }

  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

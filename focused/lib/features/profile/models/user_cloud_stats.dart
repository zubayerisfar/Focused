class UserCloudStats {
  final int streakDays;
  final int longestStreak;
  final int totalFocusMinutes;
  final int completedSessionsCount;
  final List<String> unlockedBadgeIds;
  final DateTime? updatedAt;

  // XP / Gem System
  final int xpPoints;
  final int xpAdsWatchedToday;
  final String? xpAdsWatchedDate; // ISO8601 date-only string (yyyy-MM-dd)
  final DateTime?
  xpAdsCooldownUntil; // Timestamp when watching ads is unblocked

  /// Restored calendar days (yyyy-MM-dd) to preserve restored streaks
  final List<String> restoredStreakDates;

  const UserCloudStats({
    this.streakDays = 0,
    this.longestStreak = 0,
    this.totalFocusMinutes = 0,
    this.completedSessionsCount = 0,
    this.unlockedBadgeIds = const <String>[],
    this.updatedAt,
    this.xpPoints = 0,
    this.xpAdsWatchedToday = 0,
    this.xpAdsWatchedDate,
    this.xpAdsCooldownUntil,
    this.restoredStreakDates = const <String>[],
  });

  int get gems => xpPoints;
  Duration get totalFocusDuration => Duration(minutes: totalFocusMinutes);

  UserCloudStats copyWith({
    int? streakDays,
    int? longestStreak,
    int? totalFocusMinutes,
    int? completedSessionsCount,
    List<String>? unlockedBadgeIds,
    DateTime? updatedAt,
    int? xpPoints,
    int? xpAdsWatchedToday,
    String? xpAdsWatchedDate,
    DateTime? xpAdsCooldownUntil,
    List<String>? restoredStreakDates,
    bool clearCooldown = false,
  }) {
    return UserCloudStats(
      streakDays: streakDays ?? this.streakDays,
      longestStreak: longestStreak ?? this.longestStreak,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      completedSessionsCount:
          completedSessionsCount ?? this.completedSessionsCount,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      updatedAt: updatedAt ?? this.updatedAt,
      xpPoints: xpPoints ?? this.xpPoints,
      xpAdsWatchedToday: xpAdsWatchedToday ?? this.xpAdsWatchedToday,
      xpAdsWatchedDate: xpAdsWatchedDate ?? this.xpAdsWatchedDate,
      xpAdsCooldownUntil: clearCooldown
          ? null
          : (xpAdsCooldownUntil ?? this.xpAdsCooldownUntil),
      restoredStreakDates: restoredStreakDates ?? this.restoredStreakDates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 3,
      'streakDays': streakDays,
      'longestStreak': longestStreak,
      'totalFocusMinutes': totalFocusMinutes,
      'completedSessionsCount': completedSessionsCount,
      'unlockedBadgeIds': unlockedBadgeIds,
      'updatedAt': updatedAt?.toIso8601String(),
      'xpPoints': xpPoints,
      'gems': xpPoints,
      'xpAdsWatchedToday': xpAdsWatchedToday,
      'xpAdsWatchedDate': xpAdsWatchedDate,
      'xpAdsCooldownUntil': xpAdsCooldownUntil?.toIso8601String(),
      'restoredStreakDates': restoredStreakDates,
    };
  }

  factory UserCloudStats.fromMap(Map<dynamic, dynamic> map) {
    final streak = map['streakDays'];
    final longest = map['longestStreak'];
    final focusMins = map['totalFocusMinutes'];
    final sessions = map['completedSessionsCount'];
    final badgesRaw = map['unlockedBadgeIds'];
    final updatedRaw = map['updatedAt'];
    final xp = map['xpPoints'] ?? map['gems'];
    final xpAds = map['xpAdsWatchedToday'];
    final xpDate = map['xpAdsWatchedDate'];
    final cooldownRaw = map['xpAdsCooldownUntil'];
    final restoredRaw = map['restoredStreakDates'];

    return UserCloudStats(
      streakDays: (streak is num) ? streak.toInt() : 0,
      longestStreak: (longest is num) ? longest.toInt() : 0,
      totalFocusMinutes: (focusMins is num) ? focusMins.toInt() : 0,
      completedSessionsCount: (sessions is num) ? sessions.toInt() : 0,
      unlockedBadgeIds: (badgesRaw is List)
          ? List<String>.from(badgesRaw.map((e) => e.toString()))
          : const <String>[],
      updatedAt: (updatedRaw is String) ? DateTime.tryParse(updatedRaw) : null,
      xpPoints: (xp is num) ? xp.toInt() : 0,
      xpAdsWatchedToday: (xpAds is num) ? xpAds.toInt() : 0,
      xpAdsWatchedDate: (xpDate is String) ? xpDate : null,
      xpAdsCooldownUntil: (cooldownRaw is String)
          ? DateTime.tryParse(cooldownRaw)
          : null,
      restoredStreakDates: (restoredRaw is List)
          ? List<String>.from(restoredRaw.map((e) => e.toString()))
          : const <String>[],
    );
  }
}

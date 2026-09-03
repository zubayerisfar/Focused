class UserCloudStats {
  final int streakDays;
  final int longestStreak;
  final int totalFocusMinutes;
  final int completedSessionsCount;
  final List<String> unlockedBadgeIds;
  final DateTime? updatedAt;

  // XP System
  final int xpPoints;
  final int xpAdsWatchedToday;
  final String? xpAdsWatchedDate; // ISO8601 date-only string (yyyy-MM-dd)

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
  });

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 2,
      'streakDays': streakDays,
      'longestStreak': longestStreak,
      'totalFocusMinutes': totalFocusMinutes,
      'completedSessionsCount': completedSessionsCount,
      'unlockedBadgeIds': unlockedBadgeIds,
      'updatedAt': updatedAt?.toIso8601String(),
      'xpPoints': xpPoints,
      'xpAdsWatchedToday': xpAdsWatchedToday,
      'xpAdsWatchedDate': xpAdsWatchedDate,
    };
  }

  factory UserCloudStats.fromMap(Map<dynamic, dynamic> map) {
    final streak = map['streakDays'];
    final longest = map['longestStreak'];
    final focusMins = map['totalFocusMinutes'];
    final sessions = map['completedSessionsCount'];
    final badgesRaw = map['unlockedBadgeIds'];
    final updatedRaw = map['updatedAt'];
    final xp = map['xpPoints'];
    final xpAds = map['xpAdsWatchedToday'];
    final xpDate = map['xpAdsWatchedDate'];

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
    );
  }
}

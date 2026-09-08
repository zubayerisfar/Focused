class FriendUser {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int streakDays;
  final int xpPoints;
  final int totalFocusMinutes;
  final bool isFollowing;
  final bool isSelf;
  final DateTime? lastNudgedAt;

  const FriendUser({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.streakDays = 0,
    this.xpPoints = 0,
    this.totalFocusMinutes = 0,
    this.isFollowing = false,
    this.isSelf = false,
    this.lastNudgedAt,
  });

  String get handle {
    final clean = username.trim();
    if (clean.isNotEmpty && clean != 'user') {
      return clean.startsWith('@') ? clean : '@$clean';
    }
    final nameClean = displayName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (nameClean.isNotEmpty && nameClean != 'focuseduser') {
      return '@$nameClean';
    }
    return '@user';
  }

  /// Has this friend been nudged today?
  bool get hasNudgedToday {
    if (lastNudgedAt == null) return false;
    final now = DateTime.now();
    final nudged = lastNudgedAt!.toLocal();
    return nudged.year == now.year &&
        nudged.month == now.month &&
        nudged.day == now.day;
  }

  FriendUser copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? photoUrl,
    int? streakDays,
    int? xpPoints,
    int? totalFocusMinutes,
    bool? isFollowing,
    bool? isSelf,
    DateTime? lastNudgedAt,
  }) {
    return FriendUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      streakDays: streakDays ?? this.streakDays,
      xpPoints: xpPoints ?? this.xpPoints,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      isFollowing: isFollowing ?? this.isFollowing,
      isSelf: isSelf ?? this.isSelf,
      lastNudgedAt: lastNudgedAt ?? this.lastNudgedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'streakDays': streakDays,
      'xpPoints': xpPoints,
      'gems': xpPoints,
      'totalFocusMinutes': totalFocusMinutes,
      'isFollowing': isFollowing,
      if (lastNudgedAt != null) 'lastNudgedAt': lastNudgedAt!.toIso8601String(),
    };
  }

  factory FriendUser.fromMap(
    Map<String, dynamic> map, {
    String? docId,
    bool isFollowing = false,
    bool isSelf = false,
  }) {
    final rawUsername = (map['username'] ?? map['handle'] ?? '')
        .toString()
        .trim();

    DateTime? parseNudgedAt(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final gemsVal = map['gems'] ?? map['xpPoints'];

    return FriendUser(
      uid: (docId ?? map['uid'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Focused User').toString(),
      username: rawUsername,
      photoUrl: map['photoUrl']?.toString(),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      xpPoints: (gemsVal as num?)?.toInt() ?? 0,
      totalFocusMinutes: (map['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      isFollowing: isFollowing || map['isFollowing'] == true,
      isSelf: isSelf,
      lastNudgedAt: parseNudgedAt(map['lastNudgedAt']),
    );
  }
}

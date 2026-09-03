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
      'totalFocusMinutes': totalFocusMinutes,
      'isFollowing': isFollowing,
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
    return FriendUser(
      uid: (docId ?? map['uid'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Focused User').toString(),
      username: rawUsername,
      photoUrl: map['photoUrl']?.toString(),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      xpPoints: (map['xpPoints'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (map['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      isFollowing: isFollowing || map['isFollowing'] == true,
      isSelf: isSelf,
    );
  }
}

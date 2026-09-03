class FriendUser {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;
  final int streakDays;
  final int xpPoints;
  final bool isFollowing;

  const FriendUser({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.streakDays = 0,
    this.xpPoints = 0,
    this.isFollowing = false,
  });

  String get handle {
    final clean = username.trim();
    if (clean.isNotEmpty) {
      return clean.startsWith('@') ? clean : '@$clean';
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
    bool? isFollowing,
  }) {
    return FriendUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      streakDays: streakDays ?? this.streakDays,
      xpPoints: xpPoints ?? this.xpPoints,
      isFollowing: isFollowing ?? this.isFollowing,
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
      'isFollowing': isFollowing,
    };
  }

  factory FriendUser.fromMap(Map<String, dynamic> map, {String? docId, bool isFollowing = false}) {
    return FriendUser(
      uid: (docId ?? map['uid'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Focused User').toString(),
      username: (map['username'] ?? '').toString(),
      photoUrl: map['photoUrl']?.toString(),
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      xpPoints: (map['xpPoints'] as num?)?.toInt() ?? 0,
      isFollowing: isFollowing || map['isFollowing'] == true,
    );
  }
}

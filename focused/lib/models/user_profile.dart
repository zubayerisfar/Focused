class UserProfile {
  final String displayName;
  final String email;
  final String username;
  final int joinedYear;
  final String nationality;
  final DateTime? birthday;

  const UserProfile({
    required this.displayName,
    required this.email,
    this.username = '',
    this.joinedYear = 2026,
    this.nationality = '',
    this.birthday,
  });

  /// Provides a clean display username with '@' prefix
  String get handle {
    final clean = username.trim();
    if (clean.isNotEmpty) {
      return clean.startsWith('@') ? clean : '@$clean';
    }
    // Fallback based on email or displayName
    final fallback = email.isNotEmpty
        ? email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        : displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return '@${fallback.isEmpty ? "user" : fallback}';
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? username,
    int? joinedYear,
    String? nationality,
    DateTime? birthday,
    bool clearBirthday = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      username: username ?? this.username,
      joinedYear: joinedYear ?? this.joinedYear,
      nationality: nationality ?? this.nationality,
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 3,
      'displayName': displayName,
      'email': email,
      'username': username,
      'joinedYear': joinedYear,
      'nationality': nationality,
      'birthday': birthday == null
          ? null
          : DateTime(
              birthday!.year,
              birthday!.month,
              birthday!.day,
            ).toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    final displayName = map['displayName'];
    final email = map['email'];
    if (displayName is! String || email is! String) {
      throw const FormatException('Invalid local profile.');
    }

    final rawUsername = map['username']?.toString() ?? '';
    final rawJoinedYear = (map['joinedYear'] as num?)?.toInt() ?? DateTime.now().year;
    final rawNationality = map['nationality'];
    final rawBirthday = map['birthday'];
    DateTime? birthday;
    if (rawBirthday is String && rawBirthday.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawBirthday);
      if (parsed != null) {
        birthday = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    return UserProfile(
      displayName: displayName,
      email: email,
      username: rawUsername,
      joinedYear: rawJoinedYear,
      nationality: rawNationality is String ? rawNationality : '',
      birthday: birthday,
    );
  }
}

class UserProfile {
  final String displayName;
  final String email;
  final String nationality;
  final DateTime? birthday;

  const UserProfile({
    required this.displayName,
    required this.email,
    this.nationality = '',
    this.birthday,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? nationality,
    DateTime? birthday,
    bool clearBirthday = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      nationality: nationality ?? this.nationality,
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 2,
      'displayName': displayName,
      'email': email,
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
      nationality: rawNationality is String ? rawNationality : '',
      birthday: birthday,
    );
  }
}

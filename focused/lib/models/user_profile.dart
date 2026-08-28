class UserProfile {
  final String displayName;
  final String email;

  const UserProfile({
    required this.displayName,
    required this.email,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'displayName': displayName,
      'email': email,
    };
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    final displayName = map['displayName'];
    final email = map['email'];
    if (displayName is! String || email is! String) {
      throw const FormatException('Invalid local profile.');
    }
    return UserProfile(displayName: displayName, email: email);
  }
}

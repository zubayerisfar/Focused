class PartnerQuest {
  final String partnerUid;
  final String partnerName;
  final String partnerUsername;
  final String? partnerPhotoUrl;
  final String goalTitle;
  final int totalTarget;
  final int myProgress;
  final int partnerProgress;
  final int hoursRemaining;

  const PartnerQuest({
    required this.partnerUid,
    required this.partnerName,
    required this.partnerUsername,
    this.partnerPhotoUrl,
    this.goalTitle = 'Complete 10 Focus Sessions or Tasks Together',
    this.totalTarget = 10,
    this.myProgress = 0,
    this.partnerProgress = 0,
    this.hoursRemaining = 24,
  });

  int get combinedProgress =>
      (myProgress + partnerProgress).clamp(0, totalTarget);
  double get progressRatio =>
      totalTarget == 0 ? 0 : (combinedProgress / totalTarget).clamp(0.0, 1.0);
  bool get isCompleted => combinedProgress >= totalTarget;

  PartnerQuest copyWith({
    String? partnerUid,
    String? partnerName,
    String? partnerUsername,
    String? partnerPhotoUrl,
    String? goalTitle,
    int? totalTarget,
    int? myProgress,
    int? partnerProgress,
    int? hoursRemaining,
  }) {
    return PartnerQuest(
      partnerUid: partnerUid ?? this.partnerUid,
      partnerName: partnerName ?? this.partnerName,
      partnerUsername: partnerUsername ?? this.partnerUsername,
      partnerPhotoUrl: partnerPhotoUrl ?? this.partnerPhotoUrl,
      goalTitle: goalTitle ?? this.goalTitle,
      totalTarget: totalTarget ?? this.totalTarget,
      myProgress: myProgress ?? this.myProgress,
      partnerProgress: partnerProgress ?? this.partnerProgress,
      hoursRemaining: hoursRemaining ?? this.hoursRemaining,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'partnerUsername': partnerUsername,
      'partnerPhotoUrl': partnerPhotoUrl,
      'goalTitle': goalTitle,
      'totalTarget': totalTarget,
      'myProgress': myProgress,
      'partnerProgress': partnerProgress,
      'hoursRemaining': hoursRemaining,
    };
  }

  factory PartnerQuest.fromMap(Map<String, dynamic> map) {
    return PartnerQuest(
      partnerUid: (map['partnerUid'] ?? '').toString(),
      partnerName: (map['partnerName'] ?? 'Friend').toString(),
      partnerUsername: (map['partnerUsername'] ?? '').toString(),
      partnerPhotoUrl: map['partnerPhotoUrl']?.toString(),
      goalTitle: (map['goalTitle'] ?? 'Complete 10 Focus Sessions Together')
          .toString(),
      totalTarget: (map['totalTarget'] as num?)?.toInt() ?? 10,
      myProgress: (map['myProgress'] as num?)?.toInt() ?? 0,
      partnerProgress: (map['partnerProgress'] as num?)?.toInt() ?? 0,
      hoursRemaining: (map['hoursRemaining'] as num?)?.toInt() ?? 24,
    );
  }
}

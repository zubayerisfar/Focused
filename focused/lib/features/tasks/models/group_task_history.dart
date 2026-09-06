import 'package:cloud_firestore/cloud_firestore.dart';

class GroupTaskHistoryMemberCompletion {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final DateTime? completedAt;
  final bool isLate;

  const GroupTaskHistoryMemberCompletion({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.completedAt,
    this.isLate = false,
  });

  factory GroupTaskHistoryMemberCompletion.fromMap(
    Map<String, dynamic> map, {
    String? fallbackUid,
  }) {
    return GroupTaskHistoryMemberCompletion(
      uid: map['uid']?.toString() ?? fallbackUid ?? '',
      displayName: map['displayName']?.toString() ?? 'Member',
      photoUrl: map['photoUrl'] as String?,
      completedAt: (map['completedAt'] is Timestamp)
          ? (map['completedAt'] as Timestamp).toDate()
          : (map['completedAt'] is String
                ? DateTime.tryParse(map['completedAt'])
                : null),
      isLate: map['isLate'] as bool? ?? map['completedLate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'isLate': isLate,
    };
  }
}

class GroupTaskHistory {
  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final String? category;
  final bool isHabit;
  final DateTime completedAt;
  final Map<String, GroupTaskHistoryMemberCompletion> memberCompletions;

  const GroupTaskHistory({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    this.category,
    this.isHabit = false,
    required this.completedAt,
    this.memberCompletions = const {},
  });

  factory GroupTaskHistory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawMembers = data['memberCompletions'] as Map<String, dynamic>? ?? {};
    final completions = rawMembers.map(
      (k, v) => MapEntry(
        k,
        GroupTaskHistoryMemberCompletion.fromMap(
          v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map),
          fallbackUid: k,
        ),
      ),
    );

    return GroupTaskHistory(
      id: doc.id,
      groupId: data['groupId']?.toString() ?? '',
      groupName: (data['groupName']?.toString() ?? 'TASK SQUAD').toUpperCase(),
      title: data['title']?.toString() ?? '',
      category: data['category'] as String?,
      isHabit: data['isHabit'] as bool? ?? false,
      completedAt: (data['completedAt'] is Timestamp)
          ? (data['completedAt'] as Timestamp).toDate()
          : DateTime.now(),
      memberCompletions: completions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'title': title,
      if (category != null) 'category': category,
      'isHabit': isHabit,
      'completedAt': Timestamp.fromDate(completedAt),
      'memberCompletions': memberCompletions.map(
        (k, v) => MapEntry(k, v.toMap()),
      ),
    };
  }
}

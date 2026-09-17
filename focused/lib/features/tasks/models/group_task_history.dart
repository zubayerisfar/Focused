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
    Map<dynamic, dynamic> map, {
    String? fallbackUid,
  }) {
    DateTime? parsedDate;
    final rawComp = map['completedAt'];
    if (rawComp is Timestamp) {
      parsedDate = rawComp.toDate();
    } else if (rawComp is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawComp);
    } else if (rawComp is String) {
      parsedDate = DateTime.tryParse(rawComp);
    }

    return GroupTaskHistoryMemberCompletion(
      uid: map['uid']?.toString() ?? fallbackUid ?? '',
      displayName: map['displayName']?.toString() ?? 'Member',
      photoUrl: map['photoUrl'] as String?,
      completedAt: parsedDate,
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

  factory GroupTaskHistory.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    final Map<String, GroupTaskHistoryMemberCompletion> completions = {};
    final rawMembersData = data['memberCompletions'];
    if (rawMembersData is Map) {
      rawMembersData.forEach((key, val) {
        if (val is Map) {
          final safeMap = Map<String, dynamic>.from(val);
          completions[key
              .toString()] = GroupTaskHistoryMemberCompletion.fromMap(
            safeMap,
            fallbackUid: key.toString(),
          );
        }
      });
    }

    DateTime parsedDate = DateTime.now();
    final completedAtRaw = data['completedAt'];
    final completedAtDateRaw = data['completedAtDate'];
    if (completedAtRaw is Timestamp) {
      parsedDate = completedAtRaw.toDate();
    } else if (completedAtDateRaw is Timestamp) {
      parsedDate = completedAtDateRaw.toDate();
    } else if (completedAtRaw is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(completedAtRaw);
    } else if (completedAtRaw is String) {
      parsedDate = DateTime.tryParse(completedAtRaw) ?? DateTime.now();
    }

    return GroupTaskHistory(
      id: doc.id,
      groupId: data['groupId']?.toString() ?? '',
      groupName: (data['groupName']?.toString() ?? 'TASK SQUAD').toUpperCase(),
      title: data['title']?.toString() ?? 'Squad Task',
      category: data['category'] as String?,
      isHabit: data['isHabit'] as bool? ?? false,
      completedAt: parsedDate,
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

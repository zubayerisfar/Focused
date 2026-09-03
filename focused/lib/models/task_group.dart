import 'package:cloud_firestore/cloud_firestore.dart';

class MemberTaskSchedule {
  final DateTime? scheduledTime;
  final bool completed;
  final DateTime? completedAt;

  const MemberTaskSchedule({
    this.scheduledTime,
    this.completed = false,
    this.completedAt,
  });

  factory MemberTaskSchedule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MemberTaskSchedule();
    return MemberTaskSchedule(
      scheduledTime: (map['scheduledTime'] is Timestamp)
          ? (map['scheduledTime'] as Timestamp).toDate()
          : null,
      completed: map['completed'] as bool? ?? false,
      completedAt: (map['completedAt'] is Timestamp)
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledTime': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime!)
          : null,
      'completed': completed,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  MemberTaskSchedule copyWith({
    DateTime? scheduledTime,
    bool? completed,
    DateTime? completedAt,
  }) {
    return MemberTaskSchedule(
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class GroupActiveTask {
  final String title;
  final String assignedByUid;
  final String assignedByName;
  final String assignedByUsername;
  final DateTime createdAt;
  final Map<String, MemberTaskSchedule> memberSchedules;

  const GroupActiveTask({
    required this.title,
    required this.assignedByUid,
    required this.assignedByName,
    required this.assignedByUsername,
    required this.createdAt,
    this.memberSchedules = const {},
  });

  factory GroupActiveTask.fromMap(Map<String, dynamic> map) {
    final rawSchedules = map['memberSchedules'] as Map<String, dynamic>? ?? {};
    final schedules = rawSchedules.map(
      (key, value) => MapEntry(
        key,
        MemberTaskSchedule.fromMap(value as Map<String, dynamic>?),
      ),
    );

    return GroupActiveTask(
      title: map['title']?.toString() ?? '',
      assignedByUid: map['assignedByUid']?.toString() ?? '',
      assignedByName: map['assignedByName']?.toString() ?? 'Mate',
      assignedByUsername: map['assignedByUsername']?.toString() ?? '',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      memberSchedules: schedules,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'assignedByUid': assignedByUid,
      'assignedByName': assignedByName,
      'assignedByUsername': assignedByUsername,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberSchedules': memberSchedules.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  bool isCompletedBy(String uid) {
    return memberSchedules[uid]?.completed ?? false;
  }

  DateTime? scheduledTimeFor(String uid) {
    return memberSchedules[uid]?.scheduledTime;
  }
}

class TaskGroupMember {
  final String uid;
  final String displayName;
  final String username;
  final String? photoUrl;

  const TaskGroupMember({
    required this.uid,
    required this.displayName,
    required this.username,
    this.photoUrl,
  });

  factory TaskGroupMember.fromMap(
    Map<String, dynamic> map, {
    String? fallbackUid,
  }) {
    return TaskGroupMember(
      uid: map['uid']?.toString() ?? fallbackUid ?? '',
      displayName: map['displayName']?.toString() ?? 'Mate',
      username: map['username']?.toString() ?? '',
      photoUrl: map['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
    };
  }

  String get handle => username.startsWith('@') ? username : '@$username';
}

class TaskGroup {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberUids;
  final Map<String, TaskGroupMember> members;
  final GroupActiveTask? activeTask;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberUids,
    required this.members,
    this.activeTask,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawMembers = data['members'] as Map<String, dynamic>? ?? {};
    final membersMap = rawMembers.map(
      (k, v) => MapEntry(
        k,
        TaskGroupMember.fromMap(v as Map<String, dynamic>, fallbackUid: k),
      ),
    );

    final rawActive = data['activeTask'] as Map<String, dynamic>?;
    final activeTask = (rawActive != null && rawActive['title'] != null)
        ? GroupActiveTask.fromMap(rawActive)
        : null;

    return TaskGroup(
      id: doc.id,
      name: data['name']?.toString() ?? 'Task Squad',
      createdBy: data['createdBy']?.toString() ?? '',
      memberUids:
          (data['memberUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      members: membersMap,
      activeTask: activeTask,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  bool get hasActiveTask => activeTask != null && activeTask!.title.isNotEmpty;
  bool isMember(String uid) => memberUids.contains(uid);
  bool isCreator(String uid) => createdBy == uid;
}

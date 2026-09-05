import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const List<Color> squadGroupPalette = [
  Color(0xFF9333EA), // Royal Purple
  Color(0xFF0284C7), // Ocean Blue
  Color(0xFF10B981), // Emerald Green
  Color(0xFFF59E0B), // Warm Amber
  Color(0xFFF43F5E), // Rose
  Color(0xFF6366F1), // Indigo
];

Color getSquadGroupColor(String? groupId, [int? index]) {
  if (index != null && index >= 0) {
    return squadGroupPalette[index % squadGroupPalette.length];
  }
  if (groupId == null || groupId.trim().isEmpty) {
    return squadGroupPalette[0];
  }
  final hash = groupId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return squadGroupPalette[hash.abs() % squadGroupPalette.length];
}

class MemberTaskSchedule {
  final DateTime? scheduledTime;
  final bool completed;
  final DateTime? completedAt;
  final bool completedLate;

  const MemberTaskSchedule({
    this.scheduledTime,
    this.completed = false,
    this.completedAt,
    this.completedLate = false,
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
      completedLate: map['completedLate'] as bool? ?? false,
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
      'completedLate': completedLate,
    };
  }

  MemberTaskSchedule copyWith({
    DateTime? scheduledTime,
    bool? completed,
    DateTime? completedAt,
    bool? completedLate,
  }) {
    return MemberTaskSchedule(
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      completedLate: completedLate ?? this.completedLate,
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

  final String? category;
  final bool isHabit;

  const GroupActiveTask({
    required this.title,
    required this.assignedByUid,
    required this.assignedByName,
    required this.assignedByUsername,
    required this.createdAt,
    this.memberSchedules = const {},
    this.category,
    this.isHabit = false,
  });

  String get uploaderDisplay {
    final name = assignedByName.trim();
    if (name.isNotEmpty) return name;
    final uname = assignedByUsername.trim().replaceAll('@', '');
    if (uname.isNotEmpty) return uname;
    return 'Squad Member';
  }

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
      category: map['category'] as String?,
      isHabit: map['isHabit'] as bool? ?? false,
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
      if (category != null) 'category': category,
      'isHabit': isHabit,
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
  final List<GroupActiveTask> activeTasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskGroup({
    required this.id,
    required String name,
    required this.createdBy,
    required this.memberUids,
    required this.members,
    List<GroupActiveTask>? activeTasks,
    GroupActiveTask? activeTask,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim().toUpperCase(),
       activeTasks =
           activeTasks ?? (activeTask != null ? [activeTask] : const []);

  factory TaskGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawMembers = data['members'] as Map<String, dynamic>? ?? {};
    final membersMap = rawMembers.map(
      (k, v) => MapEntry(
        k,
        TaskGroupMember.fromMap(v as Map<String, dynamic>, fallbackUid: k),
      ),
    );

    final List<GroupActiveTask> tasksList = [];
    if (data['activeTasks'] is List) {
      for (final item in (data['activeTasks'] as List)) {
        if (item is Map<String, dynamic> && item['title'] != null) {
          tasksList.add(GroupActiveTask.fromMap(item));
        }
      }
    } else {
      final rawActive = data['activeTask'] as Map<String, dynamic>?;
      if (rawActive != null && rawActive['title'] != null) {
        tasksList.add(GroupActiveTask.fromMap(rawActive));
      }
    }

    return TaskGroup(
      id: doc.id,
      name: (data['name']?.toString() ?? 'TASK SQUAD').trim().toUpperCase(),
      createdBy: data['createdBy']?.toString() ?? '',
      memberUids:
          (data['memberUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      members: membersMap,
      activeTasks: tasksList,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  GroupActiveTask? get activeTask =>
      activeTasks.isNotEmpty ? activeTasks.first : null;
  bool get hasActiveTask => activeTasks.isNotEmpty;
  bool get canAddMoreTasks => activeTasks.length < 3;
  bool isMember(String uid) => memberUids.contains(uid);
  bool isCreator(String uid) => createdBy == uid;
}

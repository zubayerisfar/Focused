import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task_group.dart';

class TaskMateService {
  final FirebaseFirestore _firestore;

  TaskMateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Streams up to 3 task groups that the current user belongs to
  Stream<List<TaskGroup>> streamMyGroups(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('task_groups')
        .where('memberUids', arrayContains: currentUid)
        .limit(3)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TaskGroup.fromFirestore(doc))
              .toList();
        });
  }

  /// Creates a new Task Mate group (up to 3 members total)
  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required List<TaskGroupMember> members,
  }) async {
    if (members.length > 5) {
      throw StateError('A Task Mate group can have at most 5 members.');
    }

    final memberUids = members.map((m) => m.uid).toList();
    final membersMap = <String, dynamic>{};
    for (final m in members) {
      membersMap[m.uid] = m.toMap();
    }

    final docRef = await _firestore.collection('task_groups').add({
      'name': name.trim().isEmpty ? 'Task Squad' : name.trim(),
      'createdBy': creatorUid,
      'memberUids': memberUids,
      'members': membersMap,
      'activeTasks': <dynamic>[],
      'activeTask': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Assigns a shared task to the group (up to 3 active tasks allowed).
  Future<bool> assignTask({
    required String groupId,
    required String title,
    required String assignerUid,
    required String assignerName,
    required String assignerUsername,
    String? category,
    bool isHabit = false,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data();
        final rawActiveTasks = (data?['activeTasks'] as List<dynamic>?) ?? [];
        if (rawActiveTasks.length >= 3) {
          // Already has 3 active tasks!
          return false;
        }

        final cleanUsername = assignerUsername.replaceAll('@', '').trim();
        final newTask = {
          'title': title.trim(),
          'assignedByUid': assignerUid,
          'assignedByName': assignerName,
          'assignedByUsername': cleanUsername,
          'category': category,
          'isHabit': isHabit,
          'createdAt': Timestamp.now(),
          'memberSchedules': <String, dynamic>{},
        };

        final updatedTasks = List<Map<String, dynamic>>.from(
          rawActiveTasks.map((t) => Map<String, dynamic>.from(t as Map)),
        )..add(newTask);

        transaction.update(docRef, {
          'activeTasks': updatedTasks,
          'activeTask': updatedTasks.first, // keep backward-compatible
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('Error assigning group task: $e');
      return false;
    }
  }

  /// Removes a task from the group (default: first task, or specific task index)
  Future<void> removeTask({required String groupId, int taskIndex = 0}) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    final rawActiveTasks = (data?['activeTasks'] as List<dynamic>?) ?? [];
    if (rawActiveTasks.isNotEmpty &&
        taskIndex >= 0 &&
        taskIndex < rawActiveTasks.length) {
      final updatedTasks = List<dynamic>.from(rawActiveTasks)
        ..removeAt(taskIndex);
      await docRef.update({
        'activeTasks': updatedTasks,
        'activeTask': updatedTasks.isNotEmpty
            ? updatedTasks.first
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'activeTasks': [],
        'activeTask': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Each member sets their own chosen scheduled time for the group task
  Future<void> scheduleMemberTime({
    required String groupId,
    required String uid,
    required DateTime scheduledTime,
    int taskIndex = 0,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    final rawActiveTasks = (data?['activeTasks'] as List<dynamic>?) ?? [];
    if (rawActiveTasks.isNotEmpty &&
        taskIndex >= 0 &&
        taskIndex < rawActiveTasks.length) {
      final updatedTasks = List<Map<String, dynamic>>.from(
        rawActiveTasks.map((t) => Map<String, dynamic>.from(t as Map)),
      );
      final targetTask = updatedTasks[taskIndex];
      final memberSchedules = Map<String, dynamic>.from(
        targetTask['memberSchedules'] as Map? ?? {},
      );
      final currentMemberSched = Map<String, dynamic>.from(
        memberSchedules[uid] as Map? ?? {},
      );
      currentMemberSched['scheduledTime'] = Timestamp.fromDate(scheduledTime);
      currentMemberSched['completed'] = false;
      memberSchedules[uid] = currentMemberSched;
      targetTask['memberSchedules'] = memberSchedules;

      await docRef.update({
        'activeTasks': updatedTasks,
        'activeTask': updatedTasks.first,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'activeTask.memberSchedules.$uid.scheduledTime': Timestamp.fromDate(
          scheduledTime,
        ),
        'activeTask.memberSchedules.$uid.completed': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Completes the task for the current member
  Future<void> completeMemberTask({
    required String groupId,
    required String uid,
    int taskIndex = 0,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    final rawActiveTasks = (data?['activeTasks'] as List<dynamic>?) ?? [];
    if (rawActiveTasks.isNotEmpty &&
        taskIndex >= 0 &&
        taskIndex < rawActiveTasks.length) {
      final updatedTasks = List<Map<String, dynamic>>.from(
        rawActiveTasks.map((t) => Map<String, dynamic>.from(t as Map)),
      );
      final targetTask = updatedTasks[taskIndex];
      final memberSchedules = Map<String, dynamic>.from(
        targetTask['memberSchedules'] as Map? ?? {},
      );
      final currentMemberSched = Map<String, dynamic>.from(
        memberSchedules[uid] as Map? ?? {},
      );
      currentMemberSched['completed'] = true;
      currentMemberSched['completedAt'] = Timestamp.now();
      memberSchedules[uid] = currentMemberSched;
      targetTask['memberSchedules'] = memberSchedules;

      await docRef.update({
        'activeTasks': updatedTasks,
        'activeTask': updatedTasks.first,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'activeTask.memberSchedules.$uid.completed': true,
        'activeTask.memberSchedules.$uid.completedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Leaves or deletes the group
  Future<void> leaveOrDeleteGroup({
    required String groupId,
    required String currentUid,
    required bool isCreator,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);

    if (isCreator) {
      await docRef.delete();
    } else {
      await docRef.update({
        'memberUids': FieldValue.arrayRemove([currentUid]),
        'members.$currentUid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

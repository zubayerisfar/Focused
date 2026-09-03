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
    if (members.length > 3) {
      throw StateError('A Task Mate group can have at most 3 members.');
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
      'activeTask': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Assigns a shared task to the group.
  /// Rule: Only one task can be active at a time. Another member cannot assign until removed.
  Future<bool> assignTask({
    required String groupId,
    required String title,
    required String assignerUid,
    required String assignerName,
    required String assignerUsername,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data();
        final currentActive = data?['activeTask'] as Map<String, dynamic>?;
        if (currentActive != null && currentActive['title'] != null) {
          // Already has an active task!
          return false;
        }

        final cleanUsername = assignerUsername.replaceAll('@', '').trim();
        final taskData = {
          'title': title.trim(),
          'assignedByUid': assignerUid,
          'assignedByName': assignerName,
          'assignedByUsername': cleanUsername,
          'createdAt': FieldValue.serverTimestamp(),
          'memberSchedules': <String, dynamic>{},
        };

        transaction.update(docRef, {
          'activeTask': taskData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('Error assigning group task: $e');
      return false;
    }
  }

  /// Removes the active task from the group (only assigner or creator can remove)
  Future<void> removeTask({required String groupId}) async {
    await _firestore.collection('task_groups').doc(groupId).update({
      'activeTask': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Each member sets their own chosen scheduled time for the group task
  Future<void> scheduleMemberTime({
    required String groupId,
    required String uid,
    required DateTime scheduledTime,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);

    await docRef.update({
      'activeTask.memberSchedules.$uid.scheduledTime': Timestamp.fromDate(
        scheduledTime,
      ),
      'activeTask.memberSchedules.$uid.completed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Completes the task for the current member
  Future<void> completeMemberTask({
    required String groupId,
    required String uid,
  }) async {
    final docRef = _firestore.collection('task_groups').doc(groupId);

    await docRef.update({
      'activeTask.memberSchedules.$uid.completed': true,
      'activeTask.memberSchedules.$uid.completedAt':
          FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

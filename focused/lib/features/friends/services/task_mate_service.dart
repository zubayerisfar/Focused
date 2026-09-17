import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../tasks/models/task_group.dart';
import '../../tasks/models/group_task_history.dart';

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

  /// Fetches task history once across the user's groups and user's own history backup
  Future<List<GroupTaskHistory>> fetchGroupsHistory(
    List<String> groupIds, {
    String? currentUid,
  }) async {
    final all = <GroupTaskHistory>[];
    final seenIds = <String>{};

    // 1. Fetch from squad history collections
    for (final gId in groupIds.take(10)) {
      try {
        final snap = await _firestore
            .collection('task_groups')
            .doc(gId)
            .collection('history')
            .get();
        for (final doc in snap.docs) {
          try {
            final item = GroupTaskHistory.fromFirestore(doc);
            if (seenIds.add(item.id)) {
              all.add(item);
            }
          } catch (e) {
            debugPrint('Error parsing group history doc ${doc.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error fetching history for group $gId: $e');
      }
    }

    // 2. Also fetch from user's personal group task history backup if available
    if (currentUid != null && currentUid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(currentUid)
            .collection('group_task_history')
            .get();
        for (final doc in snap.docs) {
          try {
            final item = GroupTaskHistory.fromFirestore(doc);
            if (seenIds.add(item.id)) {
              all.add(item);
            }
          } catch (e) {
            debugPrint('Error parsing user history backup doc ${doc.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error fetching personal group history backup: $e');
      }
    }

    all.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return all;
  }

  /// Streams task history across the user's groups without requiring composite indexes
  Stream<List<GroupTaskHistory>> streamGroupsHistory(
    List<String> groupIds, {
    String? currentUid,
  }) {
    late StreamController<List<GroupTaskHistory>> controller;
    final Map<String, List<GroupTaskHistory>> groupHistoryMap = {};
    List<GroupTaskHistory> userBackupHistory = [];
    final List<StreamSubscription> subscriptions = [];

    void emitMerged() {
      final seenIds = <String>{};
      final all = <GroupTaskHistory>[];

      for (final list in groupHistoryMap.values) {
        for (final item in list) {
          if (seenIds.add(item.id)) {
            all.add(item);
          }
        }
      }

      for (final item in userBackupHistory) {
        if (seenIds.add(item.id)) {
          all.add(item);
        }
      }

      all.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      if (!controller.isClosed) {
        controller.add(all);
      }
    }

    controller = StreamController<List<GroupTaskHistory>>.broadcast(
      onListen: () {
        for (final gId in groupIds.take(10)) {
          final sub = _firestore
              .collection('task_groups')
              .doc(gId)
              .collection('history')
              .snapshots()
              .listen(
                (snapshot) {
                  final list = <GroupTaskHistory>[];
                  for (final doc in snapshot.docs) {
                    try {
                      list.add(GroupTaskHistory.fromFirestore(doc));
                    } catch (e) {
                      debugPrint('Error parsing doc ${doc.id}: $e');
                    }
                  }
                  groupHistoryMap[gId] = list;
                  emitMerged();
                },
                onError: (e) {
                  debugPrint('Error streaming history for group $gId: $e');
                },
              );
          subscriptions.add(sub);
        }

        // Also stream user's personal backup
        if (currentUid != null && currentUid.isNotEmpty) {
          final userSub = _firestore
              .collection('users')
              .doc(currentUid)
              .collection('group_task_history')
              .snapshots()
              .listen(
                (snapshot) {
                  final list = <GroupTaskHistory>[];
                  for (final doc in snapshot.docs) {
                    try {
                      list.add(GroupTaskHistory.fromFirestore(doc));
                    } catch (e) {
                      debugPrint('Error parsing backup doc ${doc.id}: $e');
                    }
                  }
                  userBackupHistory = list;
                  emitMerged();
                },
                onError: (e) {
                  debugPrint('Error streaming user history backup: $e');
                },
              );
          subscriptions.add(userSub);
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  /// Deletes selected history entries
  Future<void> deleteHistoryItems(
    List<GroupTaskHistory> itemsToDelete, {
    String? currentUid,
  }) async {
    final batch = _firestore.batch();
    for (final item in itemsToDelete) {
      if (item.groupId.isNotEmpty) {
        final docRef = _firestore
            .collection('task_groups')
            .doc(item.groupId)
            .collection('history')
            .doc(item.id);
        batch.delete(docRef);
      }
      if (currentUid != null && currentUid.isNotEmpty) {
        final userDocRef = _firestore
            .collection('users')
            .doc(currentUid)
            .collection('group_task_history')
            .doc(item.id);
        batch.delete(userDocRef);
      }
    }
    await batch.commit();
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
      'name': name.trim().isEmpty ? 'TASK SQUAD' : name.trim().toUpperCase(),
      'createdBy': creatorUid,
      'memberUids': memberUids,
      'members': membersMap,
      'activeTasks': <dynamic>[],
      'activeTask': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify other members of squad creation
    final creatorName = members
        .firstWhere(
          (m) => m.uid == creatorUid,
          orElse: () => TaskGroupMember(
            uid: creatorUid,
            displayName: 'A Friend',
            username: '',
          ),
        )
        .displayName;

    final squadName = name.trim().isEmpty ? 'Task Squad' : name.trim();
    for (final m in members) {
      if (m.uid != creatorUid) {
        try {
          await _firestore
              .collection('users')
              .doc(m.uid)
              .collection('group_notices')
              .add({
                'groupId': docRef.id,
                'groupName': squadName,
                'creatorUid': creatorUid,
                'creatorName': creatorName,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}
      }
    }

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
      List<String> notifyMemberUids = [];
      String groupName = 'Task Squad';

      final success = await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data();
        final rawActiveTasks = (data?['activeTasks'] as List<dynamic>?) ?? [];
        if (rawActiveTasks.isNotEmpty) {
          // Already has an active task! (1 task per group limit)
          return false;
        }

        groupName = data?['name']?.toString() ?? 'Task Squad';
        final memberUids = (data?['memberUids'] as List<dynamic>?) ?? [];
        notifyMemberUids = memberUids
            .map((e) => e.toString())
            .where((uid) => uid != assignerUid)
            .toList();

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

      if (success && notifyMemberUids.isNotEmpty) {
        for (final memberUid in notifyMemberUids) {
          try {
            await _firestore
                .collection('users')
                .doc(memberUid)
                .collection('group_notices')
                .add({
                  'groupId': groupId,
                  'groupName': groupName,
                  'creatorUid': assignerUid,
                  'creatorName': assignerName,
                  'taskTitle': title.trim(),
                  'isTaskAssignment': true,
                  'read': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            debugPrint('Error sending group notice to $memberUid: $e');
          }
        }
      }

      return success;
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

  /// Completes the task for the current member and archives to history if all members finished
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
    final memberUids =
        (data?['memberUids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final groupName = (data?['name']?.toString() ?? 'TASK SQUAD').toUpperCase();
    final rawMembersData = data?['members'];
    final Map<String, dynamic> membersMap = {};
    if (rawMembersData is Map) {
      rawMembersData.forEach((k, v) {
        membersMap[k.toString()] = v is Map ? Map<String, dynamic>.from(v) : v;
      });
    }

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
      final scheduledTime = currentMemberSched['scheduledTime'] is Timestamp
          ? (currentMemberSched['scheduledTime'] as Timestamp).toDate()
          : null;
      final now = DateTime.now();
      // 20-minute grace window: completing within 20 mins of scheduled time is on time
      final isLate =
          scheduledTime != null &&
          now.isAfter(scheduledTime.add(const Duration(minutes: 20)));

      currentMemberSched['completed'] = true;
      currentMemberSched['completedAt'] = Timestamp.fromDate(now);
      currentMemberSched['completedLate'] = isLate;
      memberSchedules[uid] = currentMemberSched;
      targetTask['memberSchedules'] = memberSchedules;

      // Check if ALL squad members have completed this task
      final allCompleted =
          memberUids.isNotEmpty &&
          memberUids.every((mUid) {
            final rawSched = memberSchedules[mUid];
            final sched = rawSched is Map
                ? Map<String, dynamic>.from(rawSched)
                : null;
            return sched?['completed'] == true;
          });

      // Record completion to group history in Firebase immediately
      try {
        final historyMembers = <String, dynamic>{};
        for (final mUid in memberUids) {
          final rawSched = memberSchedules[mUid];
          final sched = rawSched is Map
              ? Map<String, dynamic>.from(rawSched)
              : null;
          final rawMData = membersMap[mUid];
          final mData = rawMData is Map
              ? Map<String, dynamic>.from(rawMData)
              : null;
          if (sched?['completed'] == true) {
            historyMembers[mUid] = {
              'uid': mUid,
              'displayName': mData?['displayName'] ?? 'Member',
              'photoUrl': mData?['photoUrl'],
              'completedAt': sched?['completedAt'] ?? Timestamp.fromDate(now),
              'isLate': sched?['completedLate'] ?? false,
            };
          }
        }

        final taskHistoryDocId =
            targetTask['id']?.toString() ??
            'hist_${targetTask['title'].toString().hashCode.abs()}';

        final historyPayload = {
          'groupId': groupId,
          'groupName': groupName,
          'title': targetTask['title'] ?? 'Squad Task',
          if (targetTask['category'] != null)
            'category': targetTask['category'],
          'isHabit': targetTask['isHabit'] ?? false,
          'completedAt': FieldValue.serverTimestamp(),
          'completedAtDate': Timestamp.fromDate(now),
          'memberCompletions': historyMembers,
        };

        // Write to squad history
        await docRef
            .collection('history')
            .doc(taskHistoryDocId)
            .set(historyPayload, SetOptions(merge: true));

        // Also write to user's personal backup history collection
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('group_task_history')
            .doc(taskHistoryDocId)
            .set(historyPayload, SetOptions(merge: true));

        // If ALL squad members have completed, remove from activeTasks
        if (allCompleted) {
          updatedTasks.removeAt(taskIndex);
        }
      } catch (e) {
        debugPrint('Error saving completed group task to history: $e');
      }

      await docRef.update({
        'activeTasks': updatedTasks,
        'activeTask': updatedTasks.isNotEmpty
            ? updatedTasks.first
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final now = DateTime.now();
      final activeTask = data?['activeTask'] is Map
          ? Map<String, dynamic>.from(data!['activeTask'] as Map)
          : null;
      if (activeTask != null) {
        final taskTitle = activeTask['title']?.toString() ?? 'Squad Task';
        final taskHistoryDocId =
            activeTask['id']?.toString() ?? 'hist_${taskTitle.hashCode.abs()}';
        final historyMembers = <String, dynamic>{
          uid: {
            'uid': uid,
            'displayName': membersMap[uid]?['displayName'] ?? 'Member',
            'photoUrl': membersMap[uid]?['photoUrl'],
            'completedAt': Timestamp.fromDate(now),
            'isLate': false,
          },
        };
        try {
          final fallbackPayload = {
            'groupId': groupId,
            'groupName': groupName,
            'title': taskTitle,
            if (activeTask['category'] != null)
              'category': activeTask['category'],
            'isHabit': activeTask['isHabit'] ?? false,
            'completedAt': FieldValue.serverTimestamp(),
            'completedAtDate': Timestamp.fromDate(now),
            'memberCompletions': historyMembers,
          };

          await docRef
              .collection('history')
              .doc(taskHistoryDocId)
              .set(fallbackPayload, SetOptions(merge: true));

          await _firestore
              .collection('users')
              .doc(uid)
              .collection('group_task_history')
              .doc(taskHistoryDocId)
              .set(fallbackPayload, SetOptions(merge: true));
        } catch (e) {
          debugPrint(
            'Error saving completed fallback group task to history: $e',
          );
        }
      }

      await docRef.update({
        'activeTask.memberSchedules.$uid.completed': true,
        'activeTask.memberSchedules.$uid.completedAt': Timestamp.fromDate(now),
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

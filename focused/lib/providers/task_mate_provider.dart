import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/friend_user.dart';
import '../models/habit.dart';
import '../models/task.dart';
import '../models/task_group.dart';
import '../models/task_recurrence.dart';
import '../services/friends_service.dart';
import '../services/task_mate_service.dart';
import '../services/task_notification_service.dart';
import 'habit_provider.dart';
import 'task_provider.dart';
import 'user_profile_provider.dart';
import 'user_stats_provider.dart';

class TaskMateProvider extends ChangeNotifier {
  final TaskMateService _service;
  final TaskNotificationService _notificationService;
  final UserStatsProvider _statsProvider;
  final UserProfileProvider _profileProvider;
  final FriendsService? _friendsService;
  TaskProvider? _taskProvider;
  HabitProvider? _habitProvider;

  String _currentUid = '';
  List<TaskGroup> _groups = [];
  bool _isLoading = false;
  StreamSubscription<List<TaskGroup>>? _groupsSub;

  TaskMateProvider({
    required TaskMateService service,
    required TaskNotificationService notificationService,
    required UserStatsProvider statsProvider,
    required UserProfileProvider profileProvider,
    FriendsService? friendsService,
    TaskProvider? taskProvider,
    HabitProvider? habitProvider,
  }) : _service = service,
       _notificationService = notificationService,
       _statsProvider = statsProvider,
       _profileProvider = profileProvider,
       _friendsService = friendsService,
       _taskProvider = taskProvider,
       _habitProvider = habitProvider;

  void attachProviders({
    TaskProvider? taskProvider,
    HabitProvider? habitProvider,
  }) {
    _taskProvider = taskProvider ?? _taskProvider;
    _habitProvider = habitProvider ?? _habitProvider;
  }

  List<TaskGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get canCreateGroup => _groups.length < 3;
  String get currentUid => _currentUid;
  static const int maxGroups = 3;
  static const int maxGroupFriends =
      4; // Up to 4 friends + creator = 5 members total

  void initForUser(String uid) {
    if (_currentUid == uid && _groupsSub != null) return;
    _currentUid = uid;
    _groupsSub?.cancel();

    if (uid.isEmpty) {
      _groups = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _groupsSub = _service
        .streamMyGroups(uid)
        .listen(
          (list) {
            _groups = list;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error streaming task groups: $e');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Creates a new squad with chosen friends (up to 4 friends, max 5 members).
  Future<bool> createGroup({
    required String name,
    required List<FriendUser> selectedFriends,
  }) async {
    if (!canCreateGroup) return false;
    if (selectedFriends.length > maxGroupFriends) return false;

    final myProfile = _profileProvider.profile;
    final allMembers = <TaskGroupMember>[
      TaskGroupMember(
        uid: _currentUid,
        displayName: myProfile.displayName.isNotEmpty
            ? myProfile.displayName
            : 'Me',
        username: myProfile.username.isNotEmpty
            ? myProfile.username
            : myProfile.displayName,
        photoUrl: null,
      ),
      ...selectedFriends.map(
        (f) => TaskGroupMember(
          uid: f.uid,
          displayName: f.displayName,
          username: f.username.isNotEmpty ? f.username : f.displayName,
          photoUrl: f.photoUrl,
        ),
      ),
    ];

    try {
      final newGroupId = await _service.createGroup(
        name: name,
        creatorUid: _currentUid,
        members: allMembers,
      );

      final newGroup = TaskGroup(
        id: newGroupId,
        name: name.trim().isEmpty ? 'Task Squad' : name.trim(),
        createdBy: _currentUid,
        memberUids: allMembers.map((m) => m.uid).toList(),
        members: {for (final m in allMembers) m.uid: m},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (!_groups.any((g) => g.id == newGroupId)) {
        _groups = [newGroup, ..._groups];
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Could not create task group: $e');
      return false;
    }
  }

  /// Assigns a shared task to the squad (up to 3 active tasks allowed).
  Future<bool> assignTask({
    required String groupId,
    required String title,
    String? category,
    bool isHabit = false,
  }) async {
    final myProfile = _profileProvider.profile;
    final resolvedUsername = myProfile.username.trim().isNotEmpty
        ? myProfile.username.trim()
        : (myProfile.handle.trim().isNotEmpty
              ? myProfile.handle.trim()
              : myProfile.displayName.trim());

    return _service.assignTask(
      groupId: groupId,
      title: title,
      assignerUid: _currentUid,
      assignerName: myProfile.displayName.isNotEmpty
          ? myProfile.displayName
          : 'Mate',
      assignerUsername: resolvedUsername,
      category: category,
      isHabit: isHabit,
    );
  }

  /// Removes a task from the squad (default: first task, or specific task index)
  Future<void> removeTask(String groupId, {int taskIndex = 0}) async {
    await _service.removeTask(groupId: groupId, taskIndex: taskIndex);
  }

  /// Sets current member's chosen time, schedules notifications, and auto-syncs to task list/habit
  Future<void> setMySchedule({
    required String groupId,
    required String taskTitle,
    required DateTime scheduledTime,
    DateTime? scheduledEnd,
    int? reminderMinutesBefore,
    int taskIndex = 0,
    bool isHabit = false,
  }) async {
    await _service.scheduleMemberTime(
      groupId: groupId,
      uid: _currentUid,
      scheduledTime: scheduledTime,
      taskIndex: taskIndex,
    );

    // 1. Schedule local notification on device
    await _notificationService.scheduleTaskMateReminder(
      groupId: groupId,
      taskTitle: taskTitle,
      scheduledTime: scheduledTime,
    );

    // 2. Automated Sync: Add to personal task list
    if (_taskProvider != null) {
      try {
        final end =
            scheduledEnd ?? scheduledTime.add(const Duration(minutes: 30));
        await _taskProvider!.createTask(
          title: taskTitle,
          description: '👥 Squad Quest',
          priority: TaskPriority.important,
          plannedDate: scheduledTime,
          scheduledStart: scheduledTime,
          scheduledEnd: end,
          reminderMinutesBefore: reminderMinutesBefore,
          recurrence: isHabit ? TaskRecurrence.daily : TaskRecurrence.none,
          isSquadTask: true,
          squadGroupId: groupId,
        );
      } catch (e) {
        debugPrint('Auto-sync to task list error: $e');
      }
    }

    // 3. Automated Sync: If habit category, auto-sync to habit
    if (isHabit && _habitProvider != null) {
      try {
        final habit = await _habitProvider!.createHabit(
          title: taskTitle,
          goalType: HabitGoalType.checkIn,
          targetValue: 1,
          unit: 'times',
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          iconCodePoint: Icons.check_rounded.codePoint,
          colorValue: 0xFF9B51E0,
          reminderMinutesFromMidnight:
              scheduledTime.hour * 60 + scheduledTime.minute,
        );
        debugPrint(
          'Squad habit auto-synced successfully: ${habit.title} (${habit.id})',
        );
      } catch (e, st) {
        debugPrint('Auto-sync to habit error: $e\n$st');
      }
    }
  }

  /// Marks task complete for current user, synchronizes with personal task list, and awards XP
  Future<void> completeTask({
    required String groupId,
    int taskIndex = 0,
    int xpAward = 200,
  }) async {
    await _service.completeMemberTask(
      groupId: groupId,
      uid: _currentUid,
      taskIndex: taskIndex,
    );

    // Synchronize completion with personal task list
    if (_taskProvider != null) {
      try {
        final now = DateTime.now();
        // Find squad task matching this group or task index
        final matchingTasks = _taskProvider!.tasks.where((t) {
          return (t.isSquadTask && t.squadGroupId == groupId) ||
              t.description.contains('Squad');
        }).toList();

        for (final task in matchingTasks) {
          if (task.recurrence == TaskRecurrence.none) {
            if (!task.isCompleted) {
              await _taskProvider!.setCompleted(task.id, true, time: now);
            }
          } else {
            if (!_taskProvider!.isTaskCompletedForDate(task, now)) {
              await _taskProvider!.setCompletedForDate(
                task.id,
                now,
                true,
                completedAt: now,
              );
            }
          }
        }
      } catch (e) {
        debugPrint(
          'Synchronizing squad task completion to local tasks error: $e',
        );
      }
    }

    // Synchronize completion with habits if matching
    if (_habitProvider != null) {
      try {
        final now = DateTime.now();
        for (final habit in _habitProvider!.habits) {
          if (!_habitProvider!.isCompletedForDate(habit, now)) {
            // If habit name matches squad task, toggle complete
            final group = _groups.firstWhere(
              (g) => g.id == groupId,
              orElse: () => TaskGroup(
                id: '',
                name: '',
                createdBy: '',
                memberUids: [],
                members: {},
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            if (taskIndex < group.activeTasks.length &&
                group.activeTasks[taskIndex].title.toLowerCase() ==
                    habit.title.toLowerCase()) {
              await _habitProvider!.toggleCompleted(habit.id, now);
            }
          }
        }
      } catch (e) {
        debugPrint('Synchronizing squad habit completion error: $e');
      }
    }

    // Award reward XP locally and notify listeners
    await _statsProvider.addXp(xpAward);

    // Directly persist to Firestore root user document
    if (_currentUid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .set({
              'xpPoints': FieldValue.increment(xpAward),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Direct Firestore XP increment error: $e');
      }
    }

    // Broadcast completion to other squad members so they get "friend finished task, now it's your turn!"
    if (_friendsService != null) {
      try {
        final group = _groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => TaskGroup(
            id: '',
            name: '',
            createdBy: '',
            memberUids: [],
            members: {},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (group.memberUids.isNotEmpty) {
          final taskTitle = taskIndex < group.activeTasks.length
              ? group.activeTasks[taskIndex].title
              : 'Squad Task';
          final myName = _profileProvider.profile.displayName.isNotEmpty
              ? _profileProvider.profile.displayName
              : 'Your squad mate';
          await _friendsService.notifyTaskMateCompletion(
            targetMemberUids: group.memberUids,
            completedByUid: _currentUid,
            completedByName: myName,
            taskTitle: taskTitle,
          );
        }
      } catch (e) {
        debugPrint('Error broadcasting squad task completion: $e');
      }
    }
  }

  /// Awards additional bonus XP (e.g. from watching a rewarded video ad)
  Future<void> awardBonusXp(int bonusXp) async {
    await _statsProvider.addXp(bonusXp);
    if (_currentUid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .set({
              'xpPoints': FieldValue.increment(bonusXp),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Direct Firestore bonus XP increment error: $e');
      }
    }
  }

  /// Automatically called when a task is marked complete in personal list / planner
  Future<void> syncTaskCompletionFromPersonalList(Task task) async {
    if (_currentUid.isEmpty) return;

    for (final group in _groups) {
      for (int i = 0; i < group.activeTasks.length; i++) {
        final activeTask = group.activeTasks[i];
        final isMatch =
            (task.isSquadTask && task.squadGroupId == group.id) ||
            task.title.trim().toLowerCase() ==
                activeTask.title.trim().toLowerCase();

        if (isMatch) {
          final mySchedule = activeTask.memberSchedules[_currentUid];
          final isAlreadyDone = mySchedule?.completed == true;

          if (!isAlreadyDone) {
            await completeTask(groupId: group.id, taskIndex: i);
          }
        }
      }
    }
  }

  /// Leaves or deletes group
  Future<void> leaveOrDeleteGroup({
    required String groupId,
    required bool isCreator,
  }) async {
    await _service.leaveOrDeleteGroup(
      groupId: groupId,
      currentUid: _currentUid,
      isCreator: isCreator,
    );
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    super.dispose();
  }
}

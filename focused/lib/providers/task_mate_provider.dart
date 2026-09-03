import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/friend_user.dart';
import '../models/habit.dart';
import '../models/task.dart';
import '../models/task_group.dart';
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
    TaskProvider? taskProvider,
    HabitProvider? habitProvider,
  }) : _service = service,
       _notificationService = notificationService,
       _statsProvider = statsProvider,
       _profileProvider = profileProvider,
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
        await _taskProvider!.createTask(
          title: taskTitle,
          description: 'Task Squad',
          priority: TaskPriority.important,
          plannedDate: scheduledTime,
          scheduledStart: scheduledTime,
          scheduledEnd: scheduledTime.add(const Duration(minutes: 30)),
        );
      } catch (e) {
        debugPrint('Auto-sync to task list error: $e');
      }
    }

    // 3. Automated Sync: If habit category, auto-sync to habit
    if (isHabit && _habitProvider != null) {
      try {
        await _habitProvider!.createHabit(
          title: taskTitle,
          goalType: HabitGoalType.checkIn,
          targetValue: 1,
          unit: 'times',
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          iconCodePoint: 0xe156, // check_circle
          colorValue: 0xFF58CC02,
          reminderMinutesFromMidnight:
              scheduledTime.hour * 60 + scheduledTime.minute,
        );
      } catch (e) {
        debugPrint('Auto-sync to habit error: $e');
      }
    }
  }

  /// Marks task complete for current user and awards DOUBLE XP (+200 EXP)
  Future<void> completeTask({
    required String groupId,
    int taskIndex = 0,
  }) async {
    await _service.completeMemberTask(
      groupId: groupId,
      uid: _currentUid,
      taskIndex: taskIndex,
    );

    // Award double reward: +200 EXP locally and notify listeners
    await _statsProvider.addXp(200);

    // Directly persist to Firestore root user document
    if (_currentUid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .set({
              'xpPoints': FieldValue.increment(200),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Direct Firestore XP increment error: $e');
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

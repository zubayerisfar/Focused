import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/friend_user.dart';
import '../models/task_group.dart';
import '../services/task_mate_service.dart';
import '../services/task_notification_service.dart';
import 'user_profile_provider.dart';
import 'user_stats_provider.dart';

class TaskMateProvider extends ChangeNotifier {
  final TaskMateService _service;
  final TaskNotificationService _notificationService;
  final UserStatsProvider _statsProvider;
  final UserProfileProvider _profileProvider;

  String _currentUid = '';
  List<TaskGroup> _groups = [];
  bool _isLoading = false;
  StreamSubscription<List<TaskGroup>>? _groupsSub;

  TaskMateProvider({
    required TaskMateService service,
    required TaskNotificationService notificationService,
    required UserStatsProvider statsProvider,
    required UserProfileProvider profileProvider,
  }) : _service = service,
       _notificationService = notificationService,
       _statsProvider = statsProvider,
       _profileProvider = profileProvider;

  List<TaskGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get canCreateGroup => _groups.length < 3;
  static const int maxGroups = 3;
  static const int maxGroupFriends = 2; // Up to 2 friends + creator = 3 members

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
          (groupsList) {
            _groups = groupsList;
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

  /// Creates a new Task Mate group with up to 2 friends
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
        username: myProfile.username,
        photoUrl: null,
      ),
      ...selectedFriends.map(
        (f) => TaskGroupMember(
          uid: f.uid,
          displayName: f.displayName,
          username: f.username,
          photoUrl: f.photoUrl,
        ),
      ),
    ];

    try {
      await _service.createGroup(
        name: name,
        creatorUid: _currentUid,
        members: allMembers,
      );
      return true;
    } catch (e) {
      debugPrint('Could not create task group: $e');
      return false;
    }
  }

  /// Assigns a shared task to the group. Returns false if a task is already active.
  Future<bool> assignTask({
    required String groupId,
    required String title,
  }) async {
    final myProfile = _profileProvider.profile;
    return _service.assignTask(
      groupId: groupId,
      title: title,
      assignerUid: _currentUid,
      assignerName: myProfile.displayName.isNotEmpty
          ? myProfile.displayName
          : 'Mate',
      assignerUsername: myProfile.username,
    );
  }

  /// Removes the active task from the group
  Future<void> removeTask(String groupId) async {
    await _service.removeTask(groupId: groupId);
  }

  /// Sets current member's chosen time and schedules a local notification
  Future<void> setMySchedule({
    required String groupId,
    required String taskTitle,
    required DateTime scheduledTime,
  }) async {
    await _service.scheduleMemberTime(
      groupId: groupId,
      uid: _currentUid,
      scheduledTime: scheduledTime,
    );

    // Schedule local notification on device
    await _notificationService.scheduleTaskMateReminder(
      groupId: groupId,
      taskTitle: taskTitle,
      scheduledTime: scheduledTime,
    );
  }

  /// Marks task complete for current user and awards DOUBLE XP (+200 EXP)
  Future<void> completeTask({required String groupId}) async {
    await _service.completeMemberTask(groupId: groupId, uid: _currentUid);

    // Award double reward: +200 EXP
    await _statsProvider.addXp(200);
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task_group.dart';
import '../../auth/providers/account_provider.dart';
import '../providers/task_mate_provider.dart';

class TaskMatesTab extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreateGroup;
  final Function(TaskGroup) onAssignTask;
  final Function(TaskGroup, int) onPickTime;
  final Function(TaskGroup, int) onStartTask;

  const TaskMatesTab({super.key, 
    required this.isDark,
    required this.onCreateGroup,
    required this.onAssignTask,
    required this.onPickTime,
    required this.onStartTask,
  });

  @override
  Widget build(BuildContext context) {
    final taskMateProvider = Provider.of<TaskMateProvider?>(context);
    final account = context.watch<AccountProvider>();
    final currentUid = account.user?.uid ?? '';
    final scheme = Theme.of(context).colorScheme;

    if (taskMateProvider == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.restart_alt_rounded,
                size: 48,
                color: Color(0xFF1CB0F6),
              ),
              const SizedBox(height: 12),
              Text(
                'Hot-Restart Needed',
                style: TextStyle(
                  color: isDark ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A new provider was added. Please press "R" in your terminal (or stop and re-run) to load Task Mates!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = taskMateProvider.groups;

    if (taskMateProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1CB0F6)),
      );
    }

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1CB0F6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icon/group_icon.svg',
                    width: 40,
                    height: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Task Squads Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Team up with up to 4 friends (up to 5 members total)! Upload up to 3 shared tasks/habits and earn double EXP (+200 EXP) when finished.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF77878F)
                      : scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1CB0F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                onPressed: onCreateGroup,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text(
                  'Create a Task Squad',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Row(
          children: [
            Text(
              'YOUR SQUADS (${groups.length}/3)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFF77878F)
                    : scheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (taskMateProvider.canCreateGroup)
              TextButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF1CB0F6),
                ),
                label: const Text(
                  'New Squad',
                  style: TextStyle(
                    color: Color(0xFF1CB0F6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Group Cards
        ...groups.map((group) {
          final isCreator = group.isCreator(currentUid);
          final activeCount = group.activeTasks.length;
          final memberList = group.members.values.toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showSquadDetailsSheet(
                  context,
                  group: group,
                  isDark: isDark,
                  currentUid: currentUid,
                  taskMateProvider: taskMateProvider,
                  onAssignTask: onAssignTask,
                  onPickTime: onPickTime,
                  onStartTask: onStartTask,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 112),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF132840), const Color(0xFF181D29)]
                          : [const Color(0xFFEBF5FF), const Color(0xFFF6FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(
                        alpha: isDark ? 0.35 : 0.6,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Squad Icon Badge
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1CB0F6,
                          ).withValues(alpha: isDark ? 0.25 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icon/group_icon.svg',
                          width: 34,
                          height: 34,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Squad Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: isDark
                                          ? Colors.white
                                          : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isCreator) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1CB0F6,
                                      ).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Owner',
                                      style: TextStyle(
                                        color: Color(0xFF1CB0F6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Member Avatars row & count
                            Row(
                              children: [
                                SizedBox(
                                  width:
                                      (memberList.length > 3
                                              ? 3
                                              : memberList.length) *
                                          18.0 +
                                      10,
                                  height: 24,
                                  child: Stack(
                                    children: [
                                      for (
                                        int i = 0;
                                        i <
                                            (memberList.length > 3
                                                ? 3
                                                : memberList.length);
                                        i++
                                      )
                                        Positioned(
                                          left: i * 16.0,
                                          child: CircleAvatar(
                                            radius: 11,
                                            backgroundColor: isDark
                                                ? const Color(0xFF263843)
                                                : Colors.white,
                                            child: CircleAvatar(
                                              radius: 9.5,
                                              backgroundColor: const Color(
                                                0xFF1CB0F6,
                                              ),
                                              backgroundImage:
                                                  memberList[i].photoUrl !=
                                                          null &&
                                                      memberList[i]
                                                          .photoUrl!
                                                          .isNotEmpty
                                                  ? NetworkImage(
                                                      memberList[i].photoUrl!,
                                                    )
                                                  : null,
                                              child:
                                                  memberList[i].photoUrl ==
                                                          null ||
                                                      memberList[i]
                                                          .photoUrl!
                                                          .isEmpty
                                                  ? Text(
                                                      memberList[i]
                                                              .displayName
                                                              .isNotEmpty
                                                          ? memberList[i]
                                                                .displayName[0]
                                                                .toUpperCase()
                                                          : 'M',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${group.members.length} members',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF77878F)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Active tasks badge chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: activeCount > 0
                                    ? const Color(
                                        0xFF58CC02,
                                      ).withValues(alpha: 0.15)
                                    : (isDark
                                          ? const Color(0xFF263843)
                                          : Colors.grey.withValues(
                                              alpha: 0.15,
                                            )),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activeCount > 0
                                        ? Icons.bolt_rounded
                                        : Icons.hourglass_empty_rounded,
                                    size: 13,
                                    color: activeCount > 0
                                        ? const Color(0xFF58CC02)
                                        : (isDark
                                              ? const Color(0xFF77878F)
                                              : scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    activeCount > 0
                                        ? '$activeCount/3 Tasks Active (+200 EXP)'
                                        : 'No Active Tasks (0/3)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: activeCount > 0
                                          ? const Color(0xFF58CC02)
                                          : (isDark
                                                ? const Color(0xFF77878F)
                                                : scheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron Arrow
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: isDark ? 0.3 : 0.5,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFF1CB0F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showSquadDetailsSheet(
    BuildContext context, {
    required TaskGroup group,
    required bool isDark,
    required String currentUid,
    required TaskMateProvider taskMateProvider,
    required void Function(TaskGroup) onAssignTask,
    required void Function(TaskGroup, int) onPickTime,
    required void Function(TaskGroup, int) onStartTask,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        final isCreator = group.isCreator(currentUid);

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
              ),
              child: Column(
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2B3D47)
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sheet Header (Squad Name + Menu)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1CB0F6),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icon/group_icon.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : scheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${group.members.length} members • ${group.activeTasks.length}/3 Tasks',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF77878F)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: isDark
                                ? const Color(0xFF77878F)
                                : scheme.onSurfaceVariant,
                          ),
                          color: scheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (action) {
                            Navigator.pop(sheetCtx);
                            if (action == 'delete') {
                              taskMateProvider.leaveOrDeleteGroup(
                                groupId: group.id,
                                isCreator: true,
                              );
                            } else if (action == 'leave') {
                              taskMateProvider.leaveOrDeleteGroup(
                                groupId: group.id,
                                isCreator: false,
                              );
                            }
                          },
                          itemBuilder: (popCtx) => [
                            if (isCreator)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete Squad',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'leave',
                              child: Text(
                                'Leave Squad',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  // Sheet Content: Tasks List & Details
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        // Members Row
                        Text(
                          'SQUAD MEMBERS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFF77878F)
                                : scheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: group.members.values.map((member) {
                              final isMe = member.uid == currentUid;
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isMe
                                        ? const Color(0xFF1CB0F6)
                                        : scheme.outlineVariant,
                                    width: isMe ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFF1CB0F6),
                                      backgroundImage:
                                          member.photoUrl != null &&
                                              member.photoUrl!.isNotEmpty
                                          ? NetworkImage(member.photoUrl!)
                                          : null,
                                      child:
                                          member.photoUrl == null ||
                                              member.photoUrl!.isEmpty
                                          ? Text(
                                              member.displayName.isNotEmpty
                                                  ? member.displayName[0]
                                                        .toUpperCase()
                                                  : 'M',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isMe ? 'You' : member.displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Title & Add Task Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SHARED TASKS (${group.activeTasks.length}/3)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? const Color(0xFF77878F)
                                    : scheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (group.canAddMoreTasks)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  onAssignTask(group);
                                },
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text(
                                  'Add Task',
                                  style: TextStyle(
                                    color: Color(0xFF1CB0F6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (group.activeTasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.assignment_outlined,
                                  size: 38,
                                  color: Color(0xFF1CB0F6),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No Active Tasks',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Upload up to 3 shared tasks/habits for the squad to conquer together and earn +200 EXP!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFAFBBC1)
                                        : scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1CB0F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    onAssignTask(group);
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text(
                                    'Upload Task (0/3)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          for (
                            int taskIdx = 0;
                            taskIdx < group.activeTasks.length;
                            taskIdx++
                          ) ...[
                            Builder(
                              builder: (context) {
                                final task = group.activeTasks[taskIdx];
                                final isCompleted = task.isCompletedBy(
                                  currentUid,
                                );
                                final mySchedule =
                                    task.memberSchedules[currentUid];
                                final myScheduledTime = task.scheduledTimeFor(
                                  currentUid,
                                );
                                final isAssigner =
                                    task.assignedByUid == currentUid ||
                                    group.isCreator(currentUid);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: task.isHabit
                                          ? const Color(
                                              0xFF58CC02,
                                            ).withValues(alpha: 0.5)
                                          : const Color(
                                              0xFF1CB0F6,
                                            ).withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFFB300,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '⚡ +200 EXP',
                                              style: TextStyle(
                                                color: Color(0xFFFFB300),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          if (task.isHabit) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF58CC02,
                                                ).withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                '🌱 Habit',
                                                style: TextStyle(
                                                  color: Color(0xFF58CC02),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (isAssigner)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Colors.redAccent,
                                              ),
                                              tooltip: 'Remove Task',
                                              onPressed: () {
                                                taskMateProvider.removeTask(
                                                  group.id,
                                                  taskIndex: taskIdx,
                                                );
                                                Navigator.pop(sheetCtx);
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 17.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Uploaded by ${task.uploaderDisplay}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFFAFBBC1)
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),

                                      // Members Schedule & Completion Status
                                      ...group.members.values.map((member) {
                                        final sched =
                                            task.memberSchedules[member.uid];
                                        final hasDone =
                                            sched?.completed ?? false;
                                        final hasSched =
                                            sched?.scheduledTime != null;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: const Color(
                                                  0xFF58CC02,
                                                ),
                                                backgroundImage:
                                                    member.photoUrl != null &&
                                                        member
                                                            .photoUrl!
                                                            .isNotEmpty
                                                    ? NetworkImage(
                                                        member.photoUrl!,
                                                      )
                                                    : null,
                                                child:
                                                    member.photoUrl == null ||
                                                        member.photoUrl!.isEmpty
                                                    ? Text(
                                                        member
                                                                .displayName
                                                                .isNotEmpty
                                                            ? member
                                                                  .displayName[0]
                                                                  .toUpperCase()
                                                            : 'M',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  member.uid == currentUid
                                                      ? 'You'
                                                      : member.displayName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: isDark
                                                        ? Colors.white
                                                        : scheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (hasDone)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF58CC02,
                                                    ).withValues(alpha: 0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Done',
                                                    style: TextStyle(
                                                      color: Color(0xFF58CC02),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                )
                                              else if (hasSched)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF1CB0F6,
                                                    ).withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    DateFormat('h:mm a').format(
                                                      sched!.scheduledTime!,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Color(0xFF1CB0F6),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  'No timer set',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF77878F,
                                                          )
                                                        : scheme
                                                              .onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),

                                      const SizedBox(height: 14),

                                      // Action Buttons for Current User
                                      if (isCompleted)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                mySchedule?.completedLate ==
                                                    true
                                                ? const Color(
                                                    0xFFF59E0B,
                                                  ).withValues(alpha: 0.15)
                                                : const Color(
                                                    0xFF58CC02,
                                                  ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              mySchedule?.completedLate == true
                                                  ? '⚠️ Completed (Late)'
                                                  : '🎉 Completed',
                                              style: TextStyle(
                                                color:
                                                    mySchedule?.completedLate ==
                                                        true
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF58CC02),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF37464F,
                                                          )
                                                        : scheme.outlineVariant,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 11,
                                                      ),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(sheetCtx);
                                                  onPickTime(group, taskIdx);
                                                },
                                                icon: const Icon(
                                                  Icons.schedule_rounded,
                                                  size: 16,
                                                  color: Color(0xFF1CB0F6),
                                                ),
                                                label: Text(
                                                  myScheduledTime != null
                                                      ? 'Change Timer'
                                                      : 'Set My Timer',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF58CC02,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 11,
                                                      ),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(sheetCtx);
                                                  onStartTask(group, taskIdx);
                                                },
                                                child: const Text(
                                                  'Start Task',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── CLAIM EXP BANNER ──

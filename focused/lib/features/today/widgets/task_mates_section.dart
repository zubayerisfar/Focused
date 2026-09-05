import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../friends/providers/task_mate_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_group.dart';
import '../../tasks/providers/task_provider.dart';

class TaskMatesSection extends StatelessWidget {
  final DateTime date;

  const TaskMatesSection({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final taskMateProvider = context.watch<TaskMateProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // Squad tasks for this date from TaskProvider
    final squadTasks = taskProvider
        .tasksForDate(date, includeCompleted: true)
        .where((t) => t.isSquadTask)
        .toList();
    final activeSquadTasks = squadTasks
        .where((t) => !taskProvider.isTaskCompletedForDate(t, date))
        .toList();

    // Check task mate groups with active tasks
    final groups = taskMateProvider.groups;
    final activeGroups = groups.where((g) => g.activeTasks.isNotEmpty).toList();

    final totalActiveCount = activeSquadTasks.isNotEmpty
        ? activeSquadTasks.length
        : activeGroups.fold<int>(0, (sum, g) => sum + g.activeTasks.length);

    const sectionAccent = Color(0xFF2563EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: sectionAccent.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                'assets/icon/group_task.svg',
                colorFilter: const ColorFilter.mode(
                  sectionAccent,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Task Mates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (totalActiveCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sectionAccent.withValues(alpha: isDark ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalActiveCount active',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: sectionAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton(
              tooltip: 'Open Squads',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.go('/?tab=friends'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Clean surface card - no colored overlay background, soft shadow
        if (activeSquadTasks.isEmpty && activeGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(
                  context,
                ).dividerColor.withValues(alpha: isDark ? 0.35 : 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No active squad tasks today',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Collaborate and stay accountable with mates.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/?tab=friends'),
                  child: const Text('Squads'),
                ),
              ],
            ),
          )
        else if (activeSquadTasks.isNotEmpty)
          ...activeSquadTasks.map(
            (task) => _SquadTaskTile(
              task: task,
              date: date,
            ),
          )
        else
          ...activeGroups.map(
            (group) => _GroupActiveSummaryTile(
              group: group,
            ),
          ),
      ],
    );
  }
}

class _SquadTaskTile extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _SquadTaskTile({
    required this.task,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskMateProvider = context.watch<TaskMateProvider>();

    // Dynamic group coloring: each group has its own distinct color
    final groupColor = taskMateProvider.colorForGroupId(task.squadGroupId);

    // Group name in all capital letters
    String groupName = 'TASK SQUAD';
    if (task.squadGroupId != null) {
      final matching = taskMateProvider.groups.where(
        (g) => g.id == task.squadGroupId,
      );
      if (matching.isNotEmpty) {
        groupName = matching.first.name.toUpperCase();
      }
    }

    // Task description or time
    String taskDescription = '';
    if (task.description.trim().isNotEmpty &&
        task.description.trim() != '👥 Squad Quest') {
      taskDescription = task.description.trim();
    } else if (task.scheduledStart != null && task.scheduledEnd != null) {
      taskDescription =
          '${DateFormat('h:mm a').format(task.scheduledStart!)} – ${DateFormat('h:mm a').format(task.scheduledEnd!)}';
    } else {
      taskDescription = 'Anytime today';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface, // Clean surface - no overlay coloring on home
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(
              context,
            ).dividerColor.withValues(alpha: isDark ? 0.35 : 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            // Simply clicking on them takes to that group and opens that group
            onTap: () => context.go('/?tab=friends'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Group-specific left color indicator bar
                  Container(
                    width: 4.5,
                    height: 52,
                    decoration: BoxDecoration(
                      color: groupColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/group_task.svg',
                      colorFilter: ColorFilter.mode(
                        groupColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group badge with group name in CAPITAL LETTERS & group coloring
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: groupColor.withValues(
                                  alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: groupColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Task title
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Task description / schedule
                        Text(
                          taskDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: groupColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupActiveSummaryTile extends StatelessWidget {
  final TaskGroup group;

  const _GroupActiveSummaryTile({
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskMateProvider = context.watch<TaskMateProvider>();

    // Each group gets its own coloring
    final groupColor = taskMateProvider.colorForGroupId(group.id);
    final groupNameUpper = group.name.toUpperCase();

    final taskTitle = group.activeTasks.isNotEmpty
        ? group.activeTasks.first.title
        : 'ACTIVE SQUAD';
    final taskCategory = group.activeTasks.isNotEmpty &&
            group.activeTasks.first.category != null
        ? group.activeTasks.first.category!
        : 'Squad Quest';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface, // Clean surface - no overlay coloring
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(
              context,
            ).dividerColor.withValues(alpha: isDark ? 0.35 : 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/?tab=friends'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 4.5,
                    height: 52,
                    decoration: BoxDecoration(
                      color: groupColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/group_task.svg',
                      colorFilter: ColorFilter.mode(
                        groupColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(
                              alpha: isDark ? 0.25 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            groupNameUpper,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: groupColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          taskTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          taskCategory,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: groupColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

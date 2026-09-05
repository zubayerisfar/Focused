import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../friends/providers/task_mate_provider.dart';
import '../../friends/widgets/squad_task_actions.dart';
import '../../main/views/main_shell.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_group.dart';
import '../../tasks/providers/task_provider.dart';

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

void _openSquads(BuildContext context) {
  final switched = MainShell.switchToTab(context, 3);
  if (!switched) {
    context.push('/friends');
  }
}

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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sectionAccent.withValues(alpha: isDark ? 0.28 : 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(
                child: Icon(
                  Icons.diversity_3_rounded,
                  color: sectionAccent,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openSquads(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Task Mates',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (totalActiveCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sectionAccent.withValues(
                              alpha: isDark ? 0.25 : 0.10,
                            ),
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
                      ],
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Open Squads',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openSquads(context),
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
                  onPressed: () => _openSquads(context),
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
              date: date,
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

    final focusSetupUri =
        '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}&occurrenceDate=${_dateQuery(date)}';

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
            // Clicking takes directly to the Focus start / setup page for this task
            onTap: () => context.push(focusSetupUri),
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
                  const SizedBox(width: 12),
                  // Sharp, clearly visible group icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: groupColor.withValues(alpha: isDark ? 0.50 : 0.30),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.groups_rounded,
                        color: groupColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group badge with group name in CAPITAL LETTERS & group coloring
                        // Tapping badge opens squad tab directly
                        GestureDetector(
                          onTap: () => _openSquads(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
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
                        ),
                        const SizedBox(height: 4),
                        // Task title
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
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
                  // Only the button to start the session
                  IconButton.filledTonal(
                    tooltip: 'Start Focus',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: groupColor.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      foregroundColor: groupColor,
                    ),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    onPressed: () => context.push(focusSetupUri),
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
  final DateTime date;

  const _GroupActiveSummaryTile({
    required this.group,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskProvider = context.watch<TaskProvider>();
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

    void onTilePressed() {
      // Find matching task in taskProvider if synced
      final matching = taskProvider.tasks.where(
        (t) => (t.isSquadTask && t.squadGroupId == group.id),
      );
      if (matching.isNotEmpty) {
        context.push(
          '/focus/setup?taskId=${Uri.encodeQueryComponent(matching.first.id)}&occurrenceDate=${_dateQuery(date)}',
        );
      } else {
        // Jump into Focus Mode or complete
        SquadTaskActions.startTask(context, group);
      }
    }

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
            onTap: onTilePressed,
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
                  const SizedBox(width: 12),
                  // Crisp, clearly visible icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: isDark ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: groupColor.withValues(alpha: isDark ? 0.50 : 0.30),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.groups_rounded,
                        color: groupColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _openSquads(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
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
                  // Only the button to start the session
                  IconButton.filledTonal(
                    tooltip: 'Start Focus',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: groupColor.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      foregroundColor: groupColor,
                    ),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    onPressed: onTilePressed,
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../friends/providers/task_mate_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_provider.dart';

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

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

    // Also check task mate groups with active tasks
    final groups = taskMateProvider.groups;
    final activeGroups = groups.where((g) => g.activeTasks.isNotEmpty).toList();

    const squadColor = Color(0xFF2563EB); // Royal oceanic blue accent

    final totalActiveCount = activeSquadTasks.isNotEmpty
        ? activeSquadTasks.length
        : activeGroups.fold<int>(0, (sum, g) => sum + g.activeTasks.length);

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
                color: squadColor.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                'assets/icon/group_task.svg',
                colorFilter: const ColorFilter.mode(
                  squadColor,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: squadColor.withValues(alpha: isDark ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalActiveCount active',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: squadColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton(
              tooltip: 'View Squads',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.push('/friends?tab=squads'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // No overlay coloring on the cards - clean surface styling with shadow
        if (activeSquadTasks.isEmpty && activeGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(
                  alpha: isDark ? 0.35 : 0.6,
                ),
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
                  onPressed: () => context.push('/friends?tab=squads'),
                  child: const Text('Squads'),
                ),
              ],
            ),
          )
        else if (activeSquadTasks.isNotEmpty)
          ...activeSquadTasks.map(
            (task) => _SquadTaskCard(
              task: task,
              date: date,
              squadColor: squadColor,
            ),
          )
        else
          // If active groups exist but not yet saved in task provider
          ...activeGroups.map(
            (group) => _GroupActiveSummaryCard(
              group: group,
              squadColor: squadColor,
            ),
          ),
      ],
    );
  }
}

class _SquadTaskCard extends StatelessWidget {
  final Task task;
  final DateTime date;
  final Color squadColor;

  const _SquadTaskCard({
    required this.task,
    required this.date,
    required this.squadColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taskProvider = context.read<TaskProvider>();
    final taskMateProvider = context.read<TaskMateProvider>();

    // Find group name if squadGroupId is present
    String groupName = 'Task Mate Squad';
    if (task.squadGroupId != null) {
      final matching = taskMateProvider.groups.where(
        (g) => g.id == task.squadGroupId,
      );
      if (matching.isNotEmpty) {
        groupName = matching.first.name;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface, // Clean surface - no overlay coloring
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(
              alpha: isDark ? 0.35 : 0.6,
            ),
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
            onTap: () => context.push(
              '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(date)}',
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: squadColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: squadColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/group_task.svg',
                      colorFilter: ColorFilter.mode(
                        squadColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              groupName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: squadColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          task.scheduledStart != null && task.scheduledEnd != null
                              ? '${DateFormat('h:mm a').format(task.scheduledStart!)} – ${DateFormat('h:mm a').format(task.scheduledEnd!)}'
                              : 'Anytime today',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Start focus',
                    onPressed: () => context.push(
                      '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}&occurrenceDate=${_dateQuery(date)}',
                    ),
                    icon: SvgPicture.asset(
                      'assets/icon/focus_icon.svg',
                      width: 22,
                      height: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mark done',
                    onPressed: () {
                      final isDone = taskProvider.isTaskCompletedForDate(task, date);
                      taskProvider.setCompletedForDate(task.id, date, !isDone);
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 24,
                    ),
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

class _GroupActiveSummaryCard extends StatelessWidget {
  final dynamic group;
  final Color squadColor;

  const _GroupActiveSummaryCard({
    required this.group,
    required this.squadColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface, // Clean surface - no overlay coloring
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(
              alpha: isDark ? 0.35 : 0.6,
            ),
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
            onTap: () => context.push('/friends?tab=squads'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: squadColor.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/group_task.svg',
                      colorFilter: ColorFilter.mode(
                        squadColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: squadColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          group.activeTasks.isNotEmpty
                              ? group.activeTasks.first.title
                              : 'Squad active',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../providers/task_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/app_theme.dart';

class TaskDetailsScreen extends StatelessWidget {
  final String taskId;
  final DateTime? occurrenceDate;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final task = tasks.getTaskById(taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => context.go('/?tab=planner&planner_area=tasks'),
          ),
        ),
        body: const Center(child: Text('Task not found.')),
      );
    }

    final day = _dateOnly(
      occurrenceDate ??
          task.plannedDate ??
          task.scheduledStart ??
          DateTime.now(),
    );
    final occurrence = tasks.occurrenceForTaskOnDate(task, day);
    final completed = tasks.isTaskCompletedForDate(task, day);

    final String taskTypeLabel;
    final IconData taskTypeIcon;
    if (task.recurrence == TaskRecurrence.daily) {
      taskTypeLabel = 'Daily';
      taskTypeIcon = Icons.repeat_rounded;
    } else if (task.recurrence == TaskRecurrence.weekdays) {
      taskTypeLabel = 'Weekdays';
      taskTypeIcon = Icons.repeat_rounded;
    } else if (task.recurrence == TaskRecurrence.weekly) {
      taskTypeLabel = 'Weekly';
      taskTypeIcon = Icons.repeat_rounded;
    } else if (task.recurrence == TaskRecurrence.customDays) {
      taskTypeLabel = 'Custom Days';
      taskTypeIcon = Icons.repeat_rounded;
    } else if (task.scheduledStart != null) {
      taskTypeLabel = DateFormat('MMM d').format(task.scheduledStart!);
      taskTypeIcon = Icons.calendar_today_rounded;
    } else if (task.plannedDate != null) {
      taskTypeLabel = DateFormat('MMM d').format(task.plannedDate!);
      taskTypeIcon = Icons.calendar_today_rounded;
    } else {
      taskTypeLabel = 'One-time';
      taskTypeIcon = Icons.task_alt_rounded;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/?tab=planner&planner_area=tasks');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => context.go('/?tab=planner&planner_area=tasks'),
          ),
          title: const Text('Task'),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () =>
                    context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          children: [
            _TaskHeader(task: task, completed: completed),
            if (task.description.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                task.description.trim(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _DetailsCard(
              task: task,
              day: day,
              occurrenceStart: occurrence?.start,
              occurrenceEnd: occurrence?.end,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    value: completed ? 'Completed' : 'Pending',
                    label: completed ? 'Done' : 'Incomplete',
                    icon: completed
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    iconColor: completed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    value: taskTypeLabel,
                    label: 'Task Type',
                    icon: taskTypeIcon,
                    iconColor: const Color(0xFF1CB0F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: completed
                      ? const Color(0xFF64748B)
                      : const Color(0xFF1CB0F6),
                ),
                onPressed: () async {
                  final newCompleted = !completed;
                  await tasks.setCompletedForDate(
                    task.id,
                    day,
                    newCompleted,
                    completedAt: newCompleted ? DateTime.now() : null,
                  );

                  if (newCompleted && context.mounted) {
                    final stats = context.read<UserStatsProvider>();
                    await stats.addGems(
                      UserStatsProvider.gemTaskReward,
                    ); // 20 Gems

                    // 5-second interstitial ad on task completion
                    AdService.instance.showInterstitialAd();

                    if (context.mounted) {
                      _showTaskCompletionRewardDialog(context, stats);
                    }
                  }
                },
                icon: Icon(
                  completed ? Icons.undo_rounded : Icons.check_circle_rounded,
                  size: 22,
                ),
                label: Text(
                  completed ? 'Mark incomplete' : 'Mark complete',
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.5),
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _confirmDelete(context, task),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text(
                  'Delete task',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          task.recurrence == TaskRecurrence.none
              ? 'Are you sure you want to delete "${task.title}"? This cannot be undone.'
              : 'Are you sure you want to delete the recurring task "${task.title}" and all its occurrences?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().deleteTask(task.id);
      if (context.mounted) {
        context.go('/?tab=planner&planner_area=tasks');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${task.title}"')));
      }
    }
  }
}

class _TaskHeader extends StatelessWidget {
  final Task task;
  final bool completed;

  const _TaskHeader({required this.task, required this.completed});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: completed
                ? Icon(Icons.check_rounded, color: color, size: 30)
                : SvgPicture.asset(
                    'assets/planner_page_icons/task_icon.svg',
                    width: 32,
                    height: 32,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.priority.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (completed) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Task task;
  final DateTime day;
  final DateTime? occurrenceStart;
  final DateTime? occurrenceEnd;

  const _DetailsCard({
    required this.task,
    required this.day,
    required this.occurrenceStart,
    required this.occurrenceEnd,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_DetailRow>[
      _DetailRow(
        icon: Icons.calendar_today_outlined,
        label: 'Date',
        value: DateFormat('EEEE, MMM d').format(day),
      ),
      if (occurrenceStart != null && occurrenceEnd != null)
        _DetailRow(
          icon: Icons.schedule_rounded,
          label: 'Time',
          value:
              '${DateFormat('h:mm a').format(occurrenceStart!)} – ${DateFormat('h:mm a').format(occurrenceEnd!)}',
        ),
      if (task.recurrence != TaskRecurrence.none)
        _DetailRow(
          icon: Icons.repeat_rounded,
          label: 'Repeats',
          value: _recurrenceLabel(task),
        ),
      if (task.reminderMinutesBefore != null)
        _DetailRow(
          icon: Icons.notifications_none_rounded,
          label: 'Reminder',
          value: task.reminderMinutesBefore == 0
              ? 'At start time'
              : '${task.reminderMinutesBefore} min before',
        ),
      if (task.deadline != null)
        _DetailRow(
          icon: Icons.flag_outlined,
          label: 'Deadline',
          value: DateFormat('MMM d, h:mm a').format(task.deadline!),
        ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: isDark ? 0.35 : 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          return Column(
            children: [
              ListTile(
                leading: Icon(row.icon),
                title: Text(row.label),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (index != rows.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;

  const _MetricCard({
    required this.value,
    required this.label,
    this.icon,
    this.customIcon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withValues(alpha: isDark ? 0.35 : 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customIcon ??
              Icon(
                icon!,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
                size: 24,
              ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _recurrenceLabel(Task task) {
  switch (task.recurrence) {
    case TaskRecurrence.none:
      return 'Does not repeat';
    case TaskRecurrence.daily:
      return 'Every day';
    case TaskRecurrence.weekdays:
      return 'Weekdays';
    case TaskRecurrence.weekly:
      return 'Every week';
    case TaskRecurrence.customDays:
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final days = task.customWeekdays.toList()..sort();
      return days.map((day) => names[day - 1]).join(', ');
  }
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return AppTheme.danger;
    case TaskPriority.important:
      return AppTheme.primaryBlue;
    case TaskPriority.growth:
      return AppTheme.success;
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

void _showTaskCompletionRewardDialog(
  BuildContext context,
  UserStatsProvider stats,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;

  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: const [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Task Completed!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icon/gem.svg', width: 24, height: 24),
                const SizedBox(width: 8),
                Text(
                  '+20 Gems Earned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Great job! Watch a quick video to double your earnings to +40 Gems.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFAFBBC1) : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent bold button to double (Top)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  AdService.instance.showRewardedAd(
                    onUserEarnedReward: (reward) async {
                      await stats.addGems(20); // Add +20 bonus gems
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF10B981),
                            content: Text('💎 Reward Doubled: +40 Gems total!'),
                          ),
                        );
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text(
                  'Double to 40',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Normal claim button (Bottom)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Claim 20 Gems',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8B949E)
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

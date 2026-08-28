import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/usage_provider.dart';
import '../../services/productivity_streak_service.dart';
import '../../theme/app_theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _streakService = ProductivityStreakService();

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final usageProvider = context.watch<UsageProvider>();

    final now = DateTime.now();
    final schedule = taskProvider.scheduledOccurrencesForDate(now);
    final allTodayTasks = taskProvider.tasksForDate(
      now,
      includeCompleted: true,
    );
    final unscheduled = allTodayTasks
        .where((task) => task.scheduledStart == null)
        .toList();

    final completed = taskProvider.completedTaskCountForDate(now);
    final total = taskProvider.taskCountForDate(now);
    final focusedToday = focusProvider.focusedDurationForDate(now);
    final usageToday = usageProvider.todaySummary?.totalUsage;
    final activityDates = <DateTime>{
      ...taskProvider.completionActivityDates(),
      ...focusProvider.focusActivityDates(),
    };
    final streak = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _TodayHeader(
              streak: streak,
              focusedToday: focusedToday,
              usageToday: usageToday,
              usageConnected: usageProvider.hasUsageAccess,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(now),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMMM d').format(now),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _ProgressPill(completed: completed, total: total),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Your day', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  schedule.isEmpty
                      ? 'Nothing is fixed on the clock yet.'
                      : 'A clear timeline of what you planned.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (schedule.isEmpty)
                  const _NoPlanTimeline()
                else
                  _TodayTimeline(occurrences: schedule, now: now),
                if (unscheduled.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Anytime today',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...unscheduled.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AnytimeTaskRow(task: task, date: now),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  final int streak;
  final Duration focusedToday;
  final Duration? usageToday;
  final bool usageConnected;

  const _TodayHeader({
    required this.streak,
    required this.focusedToday,
    required this.usageToday,
    required this.usageConnected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Focused',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Digital wellbeing',
                onPressed: () => context.push('/wellbeing'),
                icon: const Icon(Icons.insights_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatusMetric(
                    icon: Icons.local_fire_department_rounded,
                    value: '$streak',
                    label: 'day streak',
                    accent: AppTheme.warning,
                  ),
                ),
                _StatusDivider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: _StatusMetric(
                    icon: Icons.timer_rounded,
                    value: _formatDuration(focusedToday),
                    label: 'focus today',
                    accent: scheme.primary,
                  ),
                ),
                _StatusDivider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/wellbeing'),
                    child: _StatusMetric(
                      icon: Icons.smartphone_rounded,
                      value: usageToday == null
                          ? (usageConnected ? 'No data' : 'Connect')
                          : _formatDuration(usageToday!),
                      label: 'app usage',
                      accent: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatusMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 23),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  final Color color;
  const _StatusDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 48, color: color);
  }
}

class _ProgressPill extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressPill({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        total == 0 ? 'Clear day' : '$completed / $total done',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NoPlanTimeline extends StatelessWidget {
  const _NoPlanTimeline();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOW',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 2,
                  height: 146,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wb_sunny_outlined, size: 40, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  'No plan for today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  'Your timeline is open. Add a scheduled task when you want to give part of the day a clear purpose.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.push('/task/new'),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Plan a task'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTimeline extends StatelessWidget {
  final List<TaskOccurrence> occurrences;
  final DateTime now;

  const _TodayTimeline({required this.occurrences, required this.now});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(occurrences.length, (index) {
        final occurrence = occurrences[index];
        return _TimelineEntry(
          occurrence: occurrence,
          now: now,
          isLast: index == occurrences.length - 1,
        );
      }),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final TaskOccurrence occurrence;
  final DateTime now;
  final bool isLast;

  const _TimelineEntry({
    required this.occurrence,
    required this.now,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final active =
        !now.isBefore(occurrence.start) &&
        now.isBefore(occurrence.end) &&
        !occurrence.isCompleted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text(
                DateFormat('h:mm').format(occurrence.start),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 17),
                Container(
                  width: active ? 12 : 10,
                  height: active ? 12 : 10,
                  decoration: BoxDecoration(
                    color: occurrence.isCompleted
                        ? AppTheme.success
                        : active
                        ? Theme.of(context).colorScheme.primary
                        : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: active
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.62)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push(
                    '/task/edit/${Uri.encodeComponent(task.id)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  decoration: occurrence.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CompletionButton(occurrence: occurrence),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${DateFormat('h:mm a').format(occurrence.start)} – ${DateFormat('h:mm a').format(occurrence.end)}'
                          '${active ? '  •  In progress' : ''}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                        if (!occurrence.isCompleted) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                              ),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 19,
                              ),
                              label: const Text('Start focus'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  final TaskOccurrence occurrence;

  const _CompletionButton({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: occurrence.isCompleted ? 'Undo completion' : 'Complete task',
      onPressed: () => context.read<TaskProvider>().setCompletedForDate(
        occurrence.task.id,
        occurrence.start,
        !occurrence.isCompleted,
      ),
      icon: Icon(
        occurrence.isCompleted
            ? Icons.check_circle_rounded
            : Icons.circle_outlined,
        color: occurrence.isCompleted ? AppTheme.success : null,
      ),
    );
  }
}

class _AnytimeTaskRow extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _AnytimeTaskRow({required this.task, required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final completed = taskProvider.isTaskCompletedForDate(task, date);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context
                    .read<TaskProvider>()
                    .setCompletedForDate(task.id, date, !completed),
                icon: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: completed ? AppTheme.success : null,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!completed)
                IconButton(
                  tooltip: 'Start focus',
                  onPressed: () => context.push(
                    '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
        ),
      ),
    );
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

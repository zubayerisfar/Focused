import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../models/task_recurrence.dart';
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

    final focusedToday = focusProvider.focusedDurationForDate(now);
    final sessionsToday = focusProvider.sessionCountForDate(now);
    final longestSession = focusProvider.longestFocusSessionForDate(now);

    final productivityDays = <DateTime>{
      ...taskProvider.completionActivityDates(),
      ...focusProvider.focusActivityDates(),
    };
    final streak = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: productivityDays,
    );

    final totalTasksToday = taskProvider.taskCountForDate(now);
    final completedTasksToday = taskProvider.completedTaskCountForDate(now);
    final remainingTasksToday = taskProvider.remainingTaskCountForDate(now);

    final nextTask = taskProvider.nextTask(now: now);
    final todaySchedule = taskProvider.scheduledOccurrencesForDate(now);

    final taskGroups = taskProvider.tasksByPriorityForDate(
      now,
      includeCompleted: false,
    );

    List<Task> unscheduled(List<Task> tasks) {
      return tasks.where((task) => task.scheduledStart == null).toList();
    }

    final criticalTasks = unscheduled(
      taskGroups[TaskPriority.critical] ?? const <Task>[],
    );
    final importantTasks = unscheduled(
      taskGroups[TaskPriority.important] ?? const <Task>[],
    );
    final growthTasks = unscheduled(
      taskGroups[TaskPriority.growth] ?? const <Task>[],
    );

    final currentDate = DateFormat('EEEE, MMMM d').format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text(
          _greetingFor(now),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          currentDate,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.local_fire_department_rounded,
                value: '$streak',
                label: 'Day streak',
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.timer_rounded,
                value: _formatFocusDuration(focusedToday),
                label: 'Focused today',
                iconColor: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TodayProgressCard(
          completed: completedTasksToday,
          total: totalTasksToday,
          remaining: remainingTasksToday,
        ),
        const SizedBox(height: 12),
        _FocusSummaryCard(
          sessionsToday: sessionsToday,
          focusedToday: focusedToday,
          longestSession: longestSession,
        ),
        const SizedBox(height: 24),
        Text(
          'Next task',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (nextTask != null)
          _NextTaskCard(task: nextTask)
        else
          _NoTasksCard(
            onCreateTask: () {
              context.push('/task/new');
            },
          ),
        const SizedBox(height: 26),
        _DigitalBalanceCard(
          totalUsage: usageProvider.todaySummary?.totalUsage,
          changePercent: usageProvider.todayVsYesterdayPercent,
          hasUsageAccess: usageProvider.hasUsageAccess,
          isRefreshing: usageProvider.isRefreshing,
          onTap: () {
            if (usageProvider.hasUsageAccess) {
              context.push('/wellbeing/app-usage');
            } else {
              context.push('/wellbeing/permission');
            }
          },
        ),
        const SizedBox(height: 24),
        if (criticalTasks.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Critical',
            color: Color(0xFFFF6B5E),
          ),
          const SizedBox(height: 10),
          ...criticalTasks.map(
            (task) => _TaskTile(
              task: task,
              color: const Color(0xFFFF6B5E),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (importantTasks.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Important',
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 10),
          ...importantTasks.map(
            (task) => _TaskTile(
              task: task,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (growthTasks.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Growth',
            color: Color(0xFF34B27B),
          ),
          const SizedBox(height: 10),
          ...growthTasks.map(
            (task) => _TaskTile(
              task: task,
              color: const Color(0xFF34B27B),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const _SectionTitle(
          title: 'Today\'s schedule',
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 10),
        _ScheduleCard(occurrences: todaySchedule),
        const SizedBox(height: 26),
        const _SectionTitle(
          title: 'Habits',
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 10),
        _HabitsStatusCard(
          onCreateHabit: () {
            context.push('/habit/new');
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TodayProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int remaining;

  const _TodayProgressCard({
    required this.completed,
    required this.total,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final helper = total == 0
        ? 'No tasks planned for today.'
        : remaining == 0
            ? 'Everything planned for today is complete.'
            : '$remaining ${remaining == 1 ? 'task' : 'tasks'} remaining today.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: Color(0xFF34B27B),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Today\'s progress',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                total == 0 ? '0 / 0' : '$completed / $total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.08),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helper,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusSummaryCard extends StatelessWidget {
  final int sessionsToday;
  final Duration focusedToday;
  final Duration longestSession;

  const _FocusSummaryCard({
    required this.sessionsToday,
    required this.focusedToday,
    required this.longestSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sessionsToday ${sessionsToday == 1 ? 'session' : 'sessions'} today',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  focusedToday == Duration.zero
                      ? 'No focus session recorded yet.'
                      : 'Active focus ${_formatFocusDuration(focusedToday)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          if (longestSession.inMicroseconds > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatFocusDuration(longestSession),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text(
                  'longest',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DigitalBalanceCard extends StatelessWidget {
  final Duration? totalUsage;
  final double? changePercent;
  final bool hasUsageAccess;
  final bool isRefreshing;
  final VoidCallback onTap;

  const _DigitalBalanceCard({
    required this.totalUsage,
    required this.changePercent,
    required this.hasUsageAccess,
    required this.isRefreshing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final usage = totalUsage;

    String subtitle;
    if (!hasUsageAccess) {
      subtitle = 'Connect Android Usage Access to measure real app usage.';
    } else if (isRefreshing && usage == null) {
      subtitle = 'Refreshing real app usage…';
    } else if (usage == null) {
      subtitle = 'Usage Access is connected. Tap to refresh data.';
    } else {
      final change = changePercent;
      final comparison = change == null
          ? 'no yesterday baseline yet'
          : change > 0
              ? '${change.abs().round()}% more than yesterday'
              : change < 0
                  ? '${change.abs().round()}% less than yesterday'
                  : 'same as yesterday';
      subtitle = '${_formatUsageDuration(usage)} today • $comparison';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Digital balance',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (isRefreshing) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.55),
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final Color color;

  const _TaskTile({
    required this.task,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            onTap: () async {
              try {
                await context.read<TaskProvider>().setCompleted(task.id, true);
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update the task.')),
                );
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _taskSubtitle(task),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.50),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit task',
            onPressed: () {
              context.push('/task/edit/${Uri.encodeComponent(task.id)}');
            },
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  final Task task;

  const _NextTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  task.priority.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              if (task.scheduledStart != null)
                Text(
                  DateFormat('h:mm a').format(task.scheduledStart!),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _taskSubtitle(task),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                context.push(
                  '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Focus'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTasksCard extends StatelessWidget {
  final VoidCallback onCreateTask;

  const _NoTasksCard({required this.onCreateTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 38,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 10),
          const Text(
            'Nothing to work on yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreateTask,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final List<TaskOccurrence> occurrences;

  const _ScheduleCard({required this.occurrences});

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No scheduled tasks today.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var index = 0; index < occurrences.length; index++) ...[
            _ScheduleOccurrence(occurrence: occurrences[index]),
            if (index != occurrences.length - 1)
              const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _ScheduleOccurrence extends StatelessWidget {
  final TaskOccurrence occurrence;

  const _ScheduleOccurrence({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () async {
            try {
              await context.read<TaskProvider>().setCompletedForDate(
                    task.id,
                    occurrence.start,
                    !occurrence.isCompleted,
                  );
            } catch (_) {
              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not update the task.'),
                ),
              );
            }
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: occurrence.isCompleted ? color : Colors.transparent,
              border: Border.all(
                color: color,
                width: 2,
              ),
            ),
            child: occurrence.isCompleted
                ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            DateFormat('h:mm a').format(occurrence.start),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: occurrence.isCompleted
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              context.push(
                '/task/edit/${Uri.encodeComponent(task.id)}',
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: occurrence.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (task.recurrence != TaskRecurrence.none)
                  Text(
                    task.recurrence.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.50),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: occurrence.isCompleted ? 'Task completed' : 'Start focus',
          onPressed: occurrence.isCompleted
              ? null
              : () {
                  context.push(
                    '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                  );
                },
          icon: Icon(
            occurrence.isCompleted
                ? Icons.check_circle_rounded
                : Icons.play_arrow_rounded,
          ),
        ),
      ],
    );
  }
}

class _HabitsStatusCard extends StatelessWidget {
  final VoidCallback onCreateHabit;

  const _HabitsStatusCard({required this.onCreateHabit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8E67D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF8E67D4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Habit progress is not connected yet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'No placeholder habit totals are shown on Today.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCreateHabit,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

String _greetingFor(DateTime now) {
  if (now.hour < 12) {
    return 'Good morning';
  }
  if (now.hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

String _formatFocusDuration(Duration duration) {
  if (duration.inSeconds <= 0) {
    return '0 min';
  }

  if (duration.inSeconds < 60) {
    return '<1 min';
  }

  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) {
    return '$minutes min';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

String _taskSubtitle(Task task) {
  final parts = <String>[];

  final scheduledMinutes = task.scheduledDurationMinutes;
  if (scheduledMinutes != null) {
    parts.add(_formatMinutes(scheduledMinutes));
  }

  if (task.recurrence != TaskRecurrence.none) {
    parts.add(task.recurrence.label);
  }

  if (task.deadline != null) {
    final today = DateTime.now();
    if (_sameDate(task.deadline!, today)) {
      parts.add('Due today');
    } else {
      parts.add('Due ${DateFormat('d MMM').format(task.deadline!)}');
    }
  }

  if (parts.isEmpty) {
    parts.add('Flexible task');
  }

  return parts.join(' • ');
}

String _formatMinutes(int minutes) {
  if (minutes < 60) {
    return '$minutes min';
  }

  final hours = minutes ~/ 60;
  final remainder = minutes % 60;

  if (remainder == 0) {
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  return '${hours}h ${remainder}m';
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return const Color(0xFFFF6B5E);
    case TaskPriority.important:
      return AppTheme.primaryBlue;
    case TaskPriority.growth:
      return const Color(0xFF34B27B);
  }
}

String _formatUsageDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

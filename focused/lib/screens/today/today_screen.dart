import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_usage_app_entry.dart';
import '../../models/habit.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/usage_provider.dart';
import '../../services/productivity_streak_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _streakService = ProductivityStreakService();

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final usageProvider = context.watch<UsageProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final account = context.watch<AccountProvider>();

    final now = DateTime.now();
    final schedule = taskProvider.scheduledOccurrencesForDate(now);
    final todayTasks = taskProvider.tasksForDate(
      now,
      includeCompleted: false,
    );
    final habits = habitProvider.habitsForDate(now);

    final next = _findNextTodayTask(
      taskProvider: taskProvider,
      schedule: schedule,
      todayTasks: todayTasks,
      now: now,
    );

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
      child: RefreshIndicator(
        onRefresh: () =>
            usageProvider.refreshPermissionAndUsage(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                streak: streak,
                photoUrl: account.photoUrl,
                displayName: account.displayName,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _DailyOverviewCard(
                      focusedToday:
                          focusProvider.focusedDurationForDate(now),
                      usageToday:
                          usageProvider.todaySummary?.totalUsage,
                      comparisonPercent:
                          usageProvider.todayVsYesterdayPercent,
                      topApps:
                          usageProvider.topAppEntriesToday(limit: 3),
                      usageConnected: usageProvider.hasUsageAccess,
                    ),
                    const SizedBox(height: 32),
                    _DailyPlanSection(
                      next: next,
                      date: now,
                    ),
                    const SizedBox(height: 32),
                    _HabitTrackerSection(
                      habits: habits,
                      date: now,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int streak;
  final String? photoUrl;
  final String displayName;

  const _HomeHeader({
    required this.streak,
    required this.photoUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Home',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/streak'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA629).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFA629).withOpacity(0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 5),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                backgroundImage:
                    photoUrl == null ? null : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Text(
                        _initials(displayName),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOverviewCard extends StatelessWidget {
  final Duration focusedToday;
  final Duration? usageToday;
  final double? comparisonPercent;
  final List<AppUsageAppEntry> topApps;
  final bool usageConnected;

  const _DailyOverviewCard({
    required this.focusedToday,
    required this.usageToday,
    required this.comparisonPercent,
    required this.topApps,
    required this.usageConnected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today at a glance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OverviewMetricCard(
                  title: 'Focused',
                  value: _formatDuration(focusedToday),
                  icon: Icons.center_focus_strong_rounded,
                  accent: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetricCard(
                  title: 'App Usage',
                  value: usageToday == null
                      ? (usageConnected ? 'No data' : 'Connect')
                      : _formatDuration(usageToday!),
                  icon: Icons.smartphone_rounded,
                  accent: AppTheme.mist,
                  trendPercent: usageToday == null
                      ? null
                      : comparisonPercent,
                  onTap: () => context.push('/wellbeing'),
                ),
              ),
            ],
          ),
          if (topApps.isNotEmpty) ...[
            const SizedBox(height: 22),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Most used apps',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  'Top apps today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _TopAppsCompactList(
              entries: topApps.take(4).toList(growable: false),
              onOpenApp: (entry) {
                final id = Uri.encodeComponent(entry.appId);
                final name = Uri.encodeQueryComponent(entry.appName);
                context.push('/wellbeing/app/$id?name=$name');
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final double? trendPercent;
  final VoidCallback? onTap;

  const _OverviewMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.trendPercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trend = trendPercent;

    final content = Container(
      height: 132,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon, size: 19, color: accent),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 5),
            _TrendText(value: trend),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: content,
    );
  }
}

class _TrendText extends StatelessWidget {
  final double value;

  const _TrendText({required this.value});

  @override
  Widget build(BuildContext context) {
    final down = value < 0;
    final flat = value.abs() < 0.5;
    final color = flat
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : down
            ? AppTheme.success
            : AppTheme.danger;
    final icon = flat
        ? Icons.remove_rounded
        : down
            ? Icons.south_east_rounded
            : Icons.north_east_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          flat ? '0%' : '${value.abs().round()}%',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}


class _TopAppsCompactList extends StatelessWidget {
  const _TopAppsCompactList({
    required this.entries,
    required this.onOpenApp,
  });

  final List<AppUsageAppEntry> entries;
  final ValueChanged<AppUsageAppEntry> onOpenApp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onOpenApp(entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      AppIcon(
                        iconBytes: entry.iconBytes,
                        appName: entry.appName,
                        size: 36,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(entry.duration),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  indent: 62,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DailyPlanSection extends StatelessWidget {
  final _NextTodayTask? next;
  final DateTime date;

  const _DailyPlanSection({
    required this.next,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Next task',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/?tab=planner'),
              child: const Text('View today'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (next == null)
          _EmptyPlanCard(date: date)
        else
          _NextTaskCard(next: next!),
      ],
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  final _NextTodayTask next;

  const _NextTaskCard({required this.next});

  @override
  Widget build(BuildContext context) {
    final task = next.task;
    final color = _priorityColor(task.priority);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(
          '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(next.date)}',
        ),
        onLongPress: () => context.push(
          '/task/edit/${Uri.encodeComponent(task.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      next.occurrence == null
                          ? 'Anytime today'
                          : '${DateFormat('h:mm a').format(next.occurrence!.start)} – ${DateFormat('h:mm a').format(next.occurrence!.end)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Start focus',
                onPressed: () => context.push(
                  '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}&occurrenceDate=${_dateQuery(next.date)}',
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

class _EmptyPlanCard extends StatelessWidget {
  final DateTime date;

  const _EmptyPlanCard({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No unfinished tasks for ${DateFormat('EEEE').format(date)}.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitTrackerSection extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;

  const _HabitTrackerSection({
    required this.habits,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final completed = habits
        .where((habit) => provider.isCompletedForDate(habit, date))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 22,
              color: AppTheme.lavender,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Today's habit tracker",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (habits.isNotEmpty)
              Text(
                '$completed/${habits.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (habits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              'No habits scheduled today.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...habits.map(
            (habit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HabitTrackerCard(
                habit: habit,
                date: date,
              ),
            ),
          ),
      ],
    );
  }
}

class _HabitTrackerCard extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const _HabitTrackerCard({
    required this.habit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final complete = provider.isCompletedForDate(habit, date);
    final progress = provider.progressForDate(habit.id, date);
    final progressText = habit.goalType == HabitGoalType.checkIn
        ? (complete ? 'Completed' : 'Tap to complete')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          '/habit/${Uri.encodeComponent(habit.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(habit.icon, color: habit.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () => provider.toggleCompleted(habit.id, date),
                icon: Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: complete ? habit.color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextTodayTask {
  final Task task;
  final TaskOccurrence? occurrence;
  final DateTime date;

  const _NextTodayTask({
    required this.task,
    required this.occurrence,
    required this.date,
  });
}

_NextTodayTask? _findNextTodayTask({
  required TaskProvider taskProvider,
  required List<TaskOccurrence> schedule,
  required List<Task> todayTasks,
  required DateTime now,
}) {
  final day = DateTime(now.year, now.month, now.day);

  final scheduled = schedule
      .where((occurrence) => !occurrence.isCompleted)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  if (scheduled.isNotEmpty) {
    final future = scheduled.where((occurrence) => occurrence.end.isAfter(now));
    final occurrence = future.isNotEmpty ? future.first : scheduled.first;
    return _NextTodayTask(
      task: occurrence.task,
      occurrence: occurrence,
      date: day,
    );
  }

  final unscheduled = todayTasks
      .where((task) => task.scheduledStart == null)
      .toList();
  if (unscheduled.isEmpty) return null;

  unscheduled.sort((a, b) => a.priority.sortOrder.compareTo(b.priority.sortOrder));
  return _NextTodayTask(
    task: unscheduled.first,
    occurrence: null,
    date: day,
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

String _cleanAppName(String value) {
  if (!value.contains('.')) return value.isEmpty ? 'Unknown app' : value;
  final parts = value.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'Unknown app';
  final last = parts.last;
  return '${last[0].toUpperCase()}${last.substring(1)}';
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

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_category.dart';
import '../../models/app_usage_app_entry.dart';
import '../../models/habit.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../models/task_recurrence.dart';
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

    final now = DateTime.now();
    final schedule = taskProvider.scheduledOccurrencesForDate(now);
    final allTodayTasks = taskProvider.tasksForDate(
      now,
      includeCompleted: true,
    );
    final unscheduled = allTodayTasks
        .where((task) => task.scheduledStart == null)
        .toList();
    final habits = habitProvider.habitsForDate(now);

    final completedTasks = taskProvider.completedTaskCountForDate(now);
    final taskCount = taskProvider.taskCountForDate(now);
    final completedHabits = habitProvider.completedHabitCountForDate(now);
    final focusedToday = focusProvider.focusedDurationForDate(now);
    final usageToday = usageProvider.todaySummary?.totalUsage;
    final topApps = usageProvider.topAppEntriesToday(limit: 3);
    final distractingUsage =
        usageProvider.usageForCategoryToday(AppCategory.distracting);
    final topDistractingApp = usageProvider.topDistractingAppToday;

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
              child: _TodayHeader(
                date: now,
                streak: streak,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _DailyOverviewCard(
                      focusedToday: focusedToday,
                      usageToday: usageToday,
                      usageConnected: usageProvider.hasUsageAccess,
                      usageRefreshing: usageProvider.isRefreshing,
                      comparisonPercent:
                          usageProvider.todayVsYesterdayPercent,
                      topApps: topApps,
                    ),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      eyebrow: 'DAILY PLAN',
                      title: 'Your schedule',
                      subtitle: schedule.isEmpty && unscheduled.isEmpty
                          ? 'Nothing is planned yet.'
                          : '${_formatPlanCount(schedule.length, unscheduled.length)} for today',
                      trailing: _CompletionPill(
                        completed: completedTasks,
                        total: taskCount,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DailyPlanCard(
                      date: now,
                      occurrences: schedule,
                      anytime: unscheduled,
                    ),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      eyebrow: 'DAILY HABITS',
                      title: 'Keep the rhythm',
                      subtitle: habits.isEmpty
                          ? 'No habits are scheduled today.'
                          : '$completedHabits of ${habits.length} complete',
                    ),
                    const SizedBox(height: 14),
                    _HabitStrip(
                      habits: habits,
                      date: now,
                    ),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      eyebrow: 'DIGITAL WELLBEING',
                      title: 'Attention check',
                      subtitle: usageProvider.hasUsageAccess
                          ? 'See where your screen time went.'
                          : 'Connect Android Usage Access for real app data.',
                    ),
                    const SizedBox(height: 14),
                    _AttentionCard(
                      hasUsageAccess: usageProvider.hasUsageAccess,
                      totalUsage: usageToday,
                      distractingUsage: distractingUsage,
                      topDistractingApp: topDistractingApp,
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

class _TodayHeader extends StatelessWidget {
  final DateTime date;
  final int streak;

  const _TodayHeader({
    required this.date,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focused',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, MMMM d').format(date),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Digital wellbeing',
                onPressed: () => context.push('/wellbeing'),
                icon: const Icon(Icons.insights_outlined),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: 7),
                Text(
                  '$streak day streak',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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

class _DailyOverviewCard extends StatelessWidget {
  final Duration focusedToday;
  final Duration? usageToday;
  final bool usageConnected;
  final bool usageRefreshing;
  final double? comparisonPercent;
  final List<AppUsageAppEntry> topApps;

  const _DailyOverviewCard({
    required this.focusedToday,
    required this.usageToday,
    required this.usageConnected,
    required this.usageRefreshing,
    required this.comparisonPercent,
    required this.topApps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today at a glance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (usageRefreshing) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.center_focus_strong_rounded,
                  iconColor: scheme.primary,
                  value: _formatDuration(focusedToday),
                  label: 'Focused',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/wellbeing'),
                  child: _OverviewMetric(
                    icon: Icons.smartphone_rounded,
                    iconColor: AppTheme.mist,
                    value: usageToday == null
                        ? (usageConnected ? 'No data' : 'Connect')
                        : _formatDuration(usageToday!),
                    label: 'App usage',
                    supporting: usageToday == null
                        ? null
                        : _comparisonLabel(comparisonPercent),
                  ),
                ),
              ),
            ],
          ),
          if (topApps.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Most used apps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/wellbeing/app-usage'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Details'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...List.generate(topApps.length, (index) {
              final entry = topApps[index];
              return _TopAppRow(
                rank: index + 1,
                appId: entry.appId,
                appName: _cleanAppName(entry.appName),
                iconBytes: entry.iconBytes,
                duration: entry.duration,
                totalUsage: usageToday,
              );
            }),
          ] else if (!usageConnected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withOpacity(0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: scheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable Usage Access to show your real most-used apps here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.push('/wellbeing/permission'),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? supporting;

  const _OverviewMetric({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.supporting,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (supporting != null) ...[
            const SizedBox(height: 4),
            Text(
              supporting!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopAppRow extends StatelessWidget {
  final int rank;
  final String appId;
  final String appName;
  final Uint8List? iconBytes;
  final Duration duration;
  final Duration? totalUsage;

  const _TopAppRow({
    required this.rank,
    required this.appId,
    required this.appName,
    required this.iconBytes,
    required this.duration,
    required this.totalUsage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMs = totalUsage?.inMilliseconds ?? 0;
    final ratio = totalMs <= 0
        ? 0.0
        : (duration.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final encodedId = Uri.encodeComponent(appId);
        final encodedName = Uri.encodeQueryComponent(appName);
        context.push('/wellbeing/app/$encodedId?name=$encodedName');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(
                  iconBytes: iconBytes,
                  appName: appName,
                  size: 38,
                  borderRadius: 11,
                  fallbackBackground:
                      scheme.primaryContainer.withOpacity(0.65),
                  fallbackForeground: scheme.onPrimaryContainer,
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(duration),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    color: AppTheme.mist,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _CompletionPill extends StatelessWidget {
  final int completed;
  final int total;

  const _CompletionPill({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$completed/$total',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DailyPlanCard extends StatelessWidget {
  final DateTime date;
  final List<TaskOccurrence> occurrences;
  final List<Task> anytime;

  const _DailyPlanCard({
    required this.date,
    required this.occurrences,
    required this.anytime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasItems = occurrences.isNotEmpty || anytime.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: !hasItems
          ? _PlanEmptyState(date: date)
          : Column(
              children: [
                ...List.generate(occurrences.length, (index) {
                  return Column(
                    children: [
                      _ScheduledPlanRow(
                        occurrence: occurrences[index],
                      ),
                      if (index != occurrences.length - 1 || anytime.isNotEmpty)
                        Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Theme.of(context).dividerColor,
                        ),
                    ],
                  );
                }),
                if (anytime.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive_rounded,
                          size: 17,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Flexible today',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(anytime.length, (index) {
                    return Column(
                      children: [
                        _AnytimePlanRow(
                          task: anytime[index],
                          date: date,
                        ),
                        if (index != anytime.length - 1)
                          Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: Theme.of(context).dividerColor,
                          ),
                      ],
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

class _ScheduledPlanRow extends StatelessWidget {
  final TaskOccurrence occurrence;

  const _ScheduledPlanRow({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final occurrenceDay = _dateOnly(occurrence.start);
    final today = _dateOnly(DateTime.now());
    final canToggle = task.recurrence == TaskRecurrence.none ||
        !occurrenceDay.isAfter(today);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push(
        '/task/edit/${Uri.encodeComponent(task.id)}',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('h:mm').format(occurrence.start),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat('a').format(occurrence.start),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: occurrence.isCompleted ? AppTheme.success : color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      decoration: occurrence.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('h:mm a').format(occurrence.start)} – ${DateFormat('h:mm a').format(occurrence.end)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (!occurrence.isCompleted)
              IconButton(
                tooltip: 'Start focus',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.push(
                  '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                ),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            IconButton(
              tooltip: occurrence.isCompleted ? 'Undo' : 'Complete',
              visualDensity: VisualDensity.compact,
              onPressed: canToggle
                  ? () => context.read<TaskProvider>().setCompletedForDate(
                        task.id,
                        occurrence.start,
                        !occurrence.isCompleted,
                      )
                  : null,
              icon: Icon(
                occurrence.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: occurrence.isCompleted ? AppTheme.success : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnytimePlanRow extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _AnytimePlanRow({
    required this.task,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final complete = provider.isTaskCompletedForDate(task, date);

    return InkWell(
      onTap: () => context.push(
        '/task/edit/${Uri.encodeComponent(task.id)}',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.task_alt_rounded, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: complete ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            IconButton(
              tooltip: complete ? 'Undo' : 'Complete',
              visualDensity: VisualDensity.compact,
              onPressed: () => context.read<TaskProvider>().setCompletedForDate(
                    task.id,
                    date,
                    !complete,
                  ),
              icon: Icon(
                complete ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: complete ? AppTheme.success : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEmptyState extends StatelessWidget {
  final DateTime date;

  const _PlanEmptyState({required this.date});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.event_available_outlined,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No plan for today',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Give part of the day a clear time block when you are ready.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.push('/task/new'),
                  icon: const Icon(Icons.add_rounded),
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

class _HabitStrip extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;

  const _HabitStrip({
    required this.habits,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withOpacity(0.42),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Icons.repeat_rounded, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Habits live separately from your schedule. Add one when you want a repeating routine.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'New habit',
              onPressed: () => context.push('/habit/new'),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: habits.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _TodayHabitCard(
            habit: habits[index],
            date: date,
          );
        },
      ),
    );
  }
}

class _TodayHabitCard extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const _TodayHabitCard({
    required this.habit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final progress = provider.progressForDate(habit.id, date);
    final completed = provider.isCompletedForDate(habit, date);
    final ratio =
        (progress / habit.targetValue).clamp(0.0, 1.0).toDouble();
    final progressLabel = habit.goalType == HabitGoalType.checkIn
        ? (completed ? 'Completed' : 'Check in')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return SizedBox(
      width: 174,
      child: Material(
        color: habit.color.withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
        ),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push(
            '/habit/${Uri.encodeComponent(habit.id)}',
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: habit.color.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        habit.icon,
                        color: habit.color,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    InkResponse(
                      radius: 22,
                      onTap: () => context
                          .read<HabitProvider>()
                          .toggleCompleted(habit.id, date),
                      child: Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: completed
                            ? habit.color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: habit.color,
                    backgroundColor: habit.color.withOpacity(0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final bool hasUsageAccess;
  final Duration? totalUsage;
  final Duration distractingUsage;
  final String? topDistractingApp;

  const _AttentionCard({
    required this.hasUsageAccess,
    required this.totalUsage,
    required this.distractingUsage,
    required this.topDistractingApp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.push(
        hasUsageAccess ? '/wellbeing' : '/wellbeing/permission',
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.lavender.withOpacity(0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                color: AppTheme.lavender,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: hasUsageAccess
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalUsage == null
                              ? 'Waiting for usage data'
                              : '${_formatDuration(distractingUsage)} distracting',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topDistractingApp == null
                              ? 'No distracting app is leading today.'
                              : 'Most distracting: ${_cleanAppName(topDistractingApp!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect app usage',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Focused needs Android Usage Access to measure real screen time.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
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

String _formatPlanCount(int scheduled, int anytime) {
  final total = scheduled + anytime;
  if (total == 1) return '1 item';
  return '$total items';
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) return '0m';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours == 0) return '${duration.inMinutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _comparisonLabel(double? percent) {
  if (percent == null) return 'No comparison yet';
  if (percent.abs() < 0.5) return 'About the same as yesterday';

  final rounded = percent.abs().round();
  return percent < 0
      ? '↓ $rounded% vs same time yesterday'
      : '↑ $rounded% vs same time yesterday';
}

String _cleanAppName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Unknown app';
  if (!trimmed.contains('.')) return trimmed;

  final parts = trimmed.split('.');
  final last = parts.isEmpty ? trimmed : parts.last;
  if (last.isEmpty) return trimmed;
  return '${last[0].toUpperCase()}${last.substring(1)}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

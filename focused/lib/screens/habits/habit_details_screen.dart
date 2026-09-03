import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../models/habit_analytics_summary.dart';
import '../../providers/habit_provider.dart';

class HabitDetailsScreen extends StatelessWidget {
  final String habitId;

  const HabitDetailsScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habit = provider.getHabitById(habitId);

    if (habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Habit not found.')),
      );
    }

    final today = DateTime.now();
    final scheduledToday = habit.occursOn(today);
    final progress = scheduledToday
        ? provider.progressForDate(habit.id, today)
        : 0;
    final completed =
        scheduledToday && provider.isCompletedForDate(habit, today);
    final analytics = provider.analyticsFor(habit, asOf: today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit'),
        actions: [
          IconButton(
            tooltip: 'Delete habit',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete habit?'),
                  content: const Text(
                    'This also removes its local progress history.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await provider.deleteHabit(habit.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
          TextButton(
            onPressed: () =>
                context.push('/habit/edit/${Uri.encodeComponent(habit.id)}'),
            child: const Text('Edit'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HabitHeader(habit: habit),
          const SizedBox(height: 24),
          if (!scheduledToday)
            _InfoCard(
              title: 'Not scheduled today',
              body:
                  'This routine is scheduled for ${_repeatText(habit).toLowerCase()}.',
            )
          else
            _TodayProgressCard(
              habit: habit,
              progress: progress,
              completed: completed,
              onDecrease:
                  habit.goalType == HabitGoalType.checkIn || progress == 0
                  ? null
                  : () => provider.setProgress(habit.id, today, progress - 1),
              onIncrease: habit.goalType == HabitGoalType.checkIn || completed
                  ? null
                  : () => provider.setProgress(habit.id, today, progress + 1),
              onToggle: () => provider.toggleCompleted(habit.id, today),
            ),
          const SizedBox(height: 24),
          _ReminderCard(habit: habit),
          const SizedBox(height: 24),
          _AnalyticsSection(habit: habit, analytics: analytics),
        ],
      ),
    );
  }

  static String _repeatText(Habit habit) {
    if (habit.weekdays.length == 7) return 'Every day';
    if (habit.weekdays.length == 5 &&
        habit.weekdays.containsAll({1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = habit.weekdays.toList()..sort();
    return days.map((day) => labels[day - 1]).join(', ');
  }
}

class _HabitHeader extends StatelessWidget {
  final Habit habit;

  const _HabitHeader({required this.habit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: habit.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(habit.icon, color: habit.color, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                HabitDetailsScreen._repeatText(habit),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Habit habit;

  const _ReminderCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final reminder = habit.reminderTime;
    final enabled = reminder != null;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              color: enabled ? habit.color : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  reminder != null
                      ? '${reminder.format(context)} • ${HabitDetailsScreen._repeatText(habit)}'
                      : 'No reminder scheduled',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                context.push('/habit/edit/${Uri.encodeComponent(habit.id)}'),
            child: Text(enabled ? 'Change' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  final Habit habit;
  final HabitAnalyticsSummary analytics;

  const _AnalyticsSection({required this.habit, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habit analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Consistency is measured only on the days this habit is scheduled.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  width: width,
                  icon: Icons.local_fire_department_rounded,
                  value: '${analytics.currentStreak}',
                  label: 'Current streak',
                  suffix: analytics.currentStreak == 1
                      ? 'occurrence'
                      : 'occurrences',
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.emoji_events_outlined,
                  value: '${analytics.bestStreak}',
                  label: 'Best streak',
                  suffix: analytics.bestStreak == 1
                      ? 'occurrence'
                      : 'occurrences',
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.date_range_rounded,
                  value: analytics.scheduledThisWeek == 0
                      ? '—'
                      : _percent(analytics.weeklyCompletionRate),
                  label: 'This week',
                  suffix:
                      '${analytics.completedThisWeek}/${analytics.scheduledThisWeek} complete',
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.calendar_month_outlined,
                  value: analytics.scheduledThisMonth == 0
                      ? '—'
                      : _percent(analytics.monthCompletionRate),
                  label: 'This month',
                  suffix:
                      '${analytics.completedThisMonth}/${analytics.scheduledThisMonth} complete',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _RateCard(habit: habit, analytics: analytics),
        const SizedBox(height: 20),
        _HistoryGrid(habit: habit, days: analytics.historyLast30Days),
      ],
    );
  }

  static String _percent(double value) => '${(value * 100).round()}%';
}

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final String suffix;

  const _MetricCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              suffix,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final Habit habit;
  final HabitAnalyticsSummary analytics;

  const _RateCard({required this.habit, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Consistency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                analytics.scheduledLast30Days == 0
                    ? '—'
                    : '${(analytics.last30DaysCompletionRate * 100).round()}%',
                style: TextStyle(
                  color: habit.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: analytics.last30DaysCompletionRate,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            color: habit.color,
            backgroundColor: habit.color.withOpacity(0.10),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                '7 days: ${analytics.completedLast7Days}/${analytics.scheduledLast7Days}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '30 days: ${analytics.completedLast30Days}/${analytics.scheduledLast30Days}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Lifetime: ${analytics.lifetimeCompleted}/${analytics.lifetimeScheduled}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  final Habit habit;
  final List<HabitHistoryDay> days;

  const _HistoryGrid({required this.habit, required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 30 days',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Filled = completed • ring = scheduled • dash = rest day',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return Tooltip(
                message:
                    '${DateFormat('MMM d').format(day.date)} • '
                    '${day.scheduled ? (day.completed ? 'Completed' : 'Not completed') : 'Rest day'}',
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: day.completed
                        ? habit.color
                        : day.scheduled
                        ? habit.color.withOpacity(0.10)
                        : scheme.surfaceContainerHighest.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: day.scheduled && !day.completed
                        ? Border.all(color: habit.color.withOpacity(0.55))
                        : null,
                  ),
                  child: day.completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : Text(
                          day.scheduled ? '${day.date.day}' : '–',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: day.scheduled
                                    ? habit.color
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayProgressCard extends StatelessWidget {
  final Habit habit;
  final int progress;
  final bool completed;
  final Future<void> Function()? onDecrease;
  final Future<void> Function()? onIncrease;
  final Future<void> Function() onToggle;

  const _TodayProgressCard({
    required this.habit,
    required this.progress,
    required this.completed,
    required this.onDecrease,
    required this.onIncrease,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            habit.goalType == HabitGoalType.checkIn
                ? (completed ? 'Completed' : 'Not completed')
                : '$progress of ${habit.targetValue} ${habit.unit}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (habit.goalType != HabitGoalType.checkIn) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (progress / habit.targetValue).clamp(0.0, 1.0),
              color: habit.color,
              backgroundColor: habit.color.withOpacity(0.10),
              minHeight: 6,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: onDecrease == null ? null : () => onDecrease!(),
                  child: const Text('− 1'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onIncrease == null ? null : () => onIncrease!(),
                  child: const Text('+ 1'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => onToggle(),
              icon: Icon(completed ? Icons.undo_rounded : Icons.check_rounded),
              label: Text(completed ? 'Undo today' : 'Complete today'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

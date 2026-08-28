import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../providers/habit_provider.dart';

class HabitDetailsScreen extends StatelessWidget {
  final String habitId;

  const HabitDetailsScreen({
    super.key,
    required this.habitId,
  });

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
    final progress = scheduledToday ? provider.progressForDate(habit.id, today) : 0;
    final completed = scheduledToday && provider.isCompletedForDate(habit, today);
    final weekStart = _startOfWeek(today);
    final weekDays = List<DateTime>.generate(7, (index) => weekStart.add(Duration(days: index)));
    final completedThisWeek = weekDays
        .where(habit.occursOn)
        .where((date) => provider.isCompletedForDate(habit, date))
        .length;
    final scheduledThisWeek = weekDays.where(habit.occursOn).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit'),
        actions: [
          TextButton(
            onPressed: () => context.push('/habit/edit/${Uri.encodeComponent(habit.id)}'),
            child: const Text('Edit'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(habit.icon, color: habit.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _repeatText(habit),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!scheduledToday)
            _InfoCard(
              title: 'Not scheduled today',
              body: 'This routine is scheduled for ${_repeatText(habit).toLowerCase()}.',
            )
          else
            _TodayProgressCard(
              habit: habit,
              progress: progress,
              completed: completed,
              onDecrease: habit.goalType == HabitGoalType.checkIn || progress == 0
                  ? null
                  : () => provider.setProgress(habit.id, today, progress - 1),
              onIncrease: habit.goalType == HabitGoalType.checkIn || completed
                  ? null
                  : () => provider.setProgress(habit.id, today, progress + 1),
              onToggle: () => provider.toggleCompleted(habit.id, today),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'This week',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                '$completedThisWeek / $scheduledThisWeek',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDays.map((date) {
                final scheduled = habit.occursOn(date);
                final done = scheduled && provider.isCompletedForDate(habit, date);
                return Column(
                  children: [
                    Text(
                      DateFormat('E').format(date).substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: done
                            ? habit.color
                            : scheduled
                                ? habit.color.withOpacity(0.10)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done
                            ? Icons.check_rounded
                            : scheduled
                                ? Icons.circle_outlined
                                : Icons.remove_rounded,
                        size: 16,
                        color: done
                            ? Colors.white
                            : scheduled
                                ? habit.color
                                : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../habits/models/habit.dart';
import '../../habits/providers/habit_provider.dart';

class HabitTrackerSection extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;

  const HabitTrackerSection({
    super.key,
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
            SvgPicture.asset(
              'assets/planner_page_icons/planner_habit_icon.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 10),
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
              child: _HabitTrackerCard(habit: habit, date: date),
            ),
          ),
      ],
    );
  }
}

class _HabitTrackerCard extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const _HabitTrackerCard({required this.habit, required this.date});

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
        onTap: () => context.push('/habit/${Uri.encodeComponent(habit.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: habit.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(habit.icon, color: habit.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: complete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  complete ? Icons.check_circle_rounded : Icons.circle_outlined,
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

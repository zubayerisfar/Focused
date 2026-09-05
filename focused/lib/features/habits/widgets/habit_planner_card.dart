import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/habit.dart';
import '../../../providers/habit_provider.dart';

class HabitPlannerCard extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const HabitPlannerCard({super.key, required this.habit, required this.date});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final progress = provider.progressForDate(habit.id, date);
    final complete = provider.isCompletedForDate(habit, date);
    final ratio = (progress / habit.targetValue).clamp(0.0, 1.0).toDouble();

    final progressText = habit.goalType == HabitGoalType.checkIn
        ? (complete ? 'Done' : 'Check in')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/habit/${Uri.encodeComponent(habit.id)}'),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Delete "${habit.title}"?'),
              content: const Text(
                'This will delete the habit and its progress history.',
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
            await context.read<HabitProvider>().deleteHabit(habit.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(habit.icon, color: habit.color, size: 26),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          progressText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (habit.reminderTime != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                habit.reminderTime!.format(context),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (habit.goalType != HabitGoalType.checkIn) ...[
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          color: habit.color,
                          backgroundColor: habit.color.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () => context.read<HabitProvider>().toggleCompleted(
                  habit.id,
                  date,
                ),
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


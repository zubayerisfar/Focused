import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task.dart';
import '../../tasks/models/task_recurrence.dart';
import '../../tasks/providers/task_provider.dart';

class ReminderItemCard extends StatelessWidget {
  final Task task;
  final DateTime date;

  const ReminderItemCard({super.key, required this.task, required this.date});

  @override
  Widget build(BuildContext context) {
    const reminderColor = Color(0xFFFF9600);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            context.push('/reminder/edit/${Uri.encodeComponent(task.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: reminderColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: reminderColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          task.scheduledStart != null
                              ? DateFormat(
                                  'h:mm a',
                                ).format(task.scheduledStart!)
                              : (task.plannedDate != null
                                    ? DateFormat(
                                        'EEE, MMM d',
                                      ).format(task.plannedDate!)
                                    : 'No time'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (task.recurrence != TaskRecurrence.none) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${task.recurrence.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: task.isCompleted ? 'Undo' : 'Complete',
                onPressed: () {
                  final now = DateTime.now();
                  context.read<TaskProvider>().setCompletedForDate(
                    task.id,
                    now,
                    !task.isCompleted,
                  );
                },
                icon: Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: task.isCompleted ? reminderColor : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


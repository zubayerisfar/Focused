import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/task_provider.dart';

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class TodayRemindersSection extends StatelessWidget {
  final DateTime date;

  const TodayRemindersSection({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allReminders = taskProvider.reminders;

    final dateReminders = allReminders.where((t) {
      if (t.scheduledStart != null) {
        return _sameDate(t.scheduledStart!, date);
      }
      if (t.plannedDate != null) {
        return _sameDate(t.plannedDate!, date);
      }
      return false;
    }).toList();

    final activeReminders = dateReminders
        .where((t) => !t.isCompleted)
        .take(3)
        .toList();

    const accent = Color(0xFFFF9600);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 22,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reminders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (activeReminders.isNotEmpty)
              Text(
                '${activeReminders.length} active',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeReminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active reminders for today.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          ...activeReminders.map(
            (reminder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push(
                    '/reminder/edit/${Uri.encodeComponent(reminder.id)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reminder.scheduledStart != null
                                    ? DateFormat(
                                        'h:mm a',
                                      ).format(reminder.scheduledStart!)
                                    : (reminder.plannedDate != null
                                          ? DateFormat(
                                              'EEE, MMM d',
                                            ).format(reminder.plannedDate!)
                                          : 'Today'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Done',
                          onPressed: () =>
                              taskProvider.setCompleted(reminder.id, true),
                          icon: const Icon(Icons.circle_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


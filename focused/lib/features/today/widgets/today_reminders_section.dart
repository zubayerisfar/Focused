import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/providers/task_provider.dart';
import '../../streak/providers/user_stats_provider.dart';

class TodayRemindersSection extends StatelessWidget {
  final DateTime date;

  const TodayRemindersSection({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final dateReminders = taskProvider.remindersForDate(
      date,
      includeCompleted: true,
    );

    final activeReminders = dateReminders
        .where((t) => !taskProvider.isTaskCompletedForDate(t, date))
        .take(3)
        .toList();

    const accent = Color(0xFFFF9600);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/planner_page_icons/planner_reminder_icon.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 10),
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
            ),
            child: Text(
              'No active reminders for today.',
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
                          onPressed: () async {
                            await taskProvider.setCompletedForDate(
                              reminder.id,
                              date,
                              true,
                            );
                            if (context.mounted) {
                              final stats = context.read<UserStatsProvider>();
                              await stats.addGems(UserStatsProvider.gemReminderReward);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Color(0xFF10B981),
                                    content: Text('💎 +10 Gems earned!'),
                                  ),
                                );
                              }
                            }
                          },
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

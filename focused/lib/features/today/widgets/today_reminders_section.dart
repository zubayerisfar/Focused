import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/providers/task_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/widgets/glass_container.dart';

class TodayRemindersSection extends StatelessWidget {
  final DateTime date;

  const TodayRemindersSection({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              'assets/today_screen_icons/reminder_icon_today_screen.svg',
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : const Color(0xFF1E293B),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reminders',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (activeReminders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${activeReminders.length} active',
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeReminders.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(22),
            child: Center(
              child: Text(
                'No active reminders for today.',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          ...activeReminders.map(
            (reminder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                borderRadius: BorderRadius.circular(22),
                onTap: () => context.push(
                  '/reminder/edit/${Uri.encodeComponent(reminder.id)}',
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
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
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
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
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Complete',
                      onPressed: () async {
                        final isDone = taskProvider.isTaskCompletedForDate(
                          reminder,
                          date,
                        );
                        await taskProvider.setCompletedForDate(
                          reminder.id,
                          date,
                          !isDone,
                        );
                        if (context.mounted) {
                          final stats = context.read<UserStatsProvider>();
                          await stats.addGems(
                            UserStatsProvider.gemReminderReward,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 2),
                                backgroundColor: Color(0xFF10B981),
                                content: Text('💎 +5 Gems earned!'),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        Icons.circle_outlined,
                        color: isDark ? Colors.white38 : Colors.black26,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

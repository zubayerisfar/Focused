import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../tasks/providers/task_provider.dart';
import '../widgets/reminder_item_card.dart';

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

class RemindersPlannerBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const RemindersPlannerBody({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allReminders = taskProvider.reminders;

    final dateReminders = allReminders.where((t) {
      if (t.scheduledStart != null) {
        return _sameDate(t.scheduledStart!, selectedDate);
      }
      if (t.plannedDate != null) {
        return _sameDate(t.plannedDate!, selectedDate);
      }
      return false;
    }).toList();

    final completedCount = dateReminders
        .where((r) => taskProvider.isTaskCompletedForDate(r, selectedDate))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateReminders.isEmpty
                        ? 'No reminders are scheduled for this date.'
                        : '$completedCount of ${dateReminders.length} complete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.push('/reminder/new'),
              child: const Text(
                'New reminder',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  fontSize: 15.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (dateReminders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withOpacity(0.4),
              ),
            ),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/planner_page_icons/planner_reminder_icon.svg',
                  width: 54,
                  height: 54,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                Text(
                  'No reminders for this date',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add reminders to get alerted for time-sensitive things.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...dateReminders.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReminderItemCard(task: task, date: selectedDate),
            ),
          ),
      ],
    );
  }
}

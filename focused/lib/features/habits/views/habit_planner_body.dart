import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/habit_provider.dart';
import '../../../theme/app_theme.dart';
import '../widgets/habit_planner_card.dart';

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _isToday(DateTime date) => _sameDate(date, DateTime.now());

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _weekStart(DateTime date) {
  final day = _dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

class HabitPlannerBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const HabitPlannerBody({super.key, 
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habits = provider.habitsForDate(selectedDate);
    final completed = habits
        .where((habit) => provider.isCompletedForDate(habit, selectedDate))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _WeekDateStripForHabits(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isToday(selectedDate)
                        ? 'Today’s habits'
                        : '${DateFormat('EEEE').format(selectedDate)} habits',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habits.isEmpty
                        ? 'No routines are scheduled for this date.'
                        : '$completed of ${habits.length} complete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.push('/habit/new'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New habit',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (habits.isEmpty)
          _HabitEmptyState(hasAny: provider.habits.isNotEmpty)
        else
          ...habits.map(
            (habit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HabitPlannerCard(habit: habit, date: selectedDate),
            ),
          ),
      ],
    );
  }
}



class _WeekDateStripForHabits extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDateStripForHabits({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(selectedDate);
    final provider = context.watch<HabitProvider>();

    return Row(
      children: List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final selected = _sameDate(date, selectedDate);
        final habits = provider.habitsForDate(date);
        final complete =
            habits.isNotEmpty &&
            habits.every((habit) => provider.isCompletedForDate(habit, date));

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onDateSelected(date),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date).substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Icon(
                      complete ? Icons.check_circle_rounded : Icons.circle,
                      size: complete ? 8 : 5,
                      color: complete
                          ? AppTheme.success
                          : habits.isNotEmpty
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}



class _HabitEmptyState extends StatelessWidget {
  final bool hasAny;

  const _HabitEmptyState({required this.hasAny});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          SvgPicture.asset('assets/icon/task_icon.svg', width: 44, height: 44),
          const SizedBox(height: 12),
          Text(
            hasAny ? 'No habits scheduled today' : 'Build your first routine',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            hasAny
                ? 'Choose another date to see its routines.'
                : 'Use the single New habit button to add a routine that repeats on the days you choose.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}


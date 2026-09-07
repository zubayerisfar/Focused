import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../widgets/habit_planner_card.dart';

class HabitPlannerBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onBack;

  const HabitPlannerBody({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habits = provider.habitsForDate(selectedDate);
    final completed = habits
        .where((habit) => provider.isCompletedForDate(habit, selectedDate))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBack != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBack,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                'Habits',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                habits.isEmpty
                    ? 'No routines are scheduled for today.'
                    : '$completed of ${habits.length} complete today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              onPressed: () => context.push('/habit/new'),
              child: const Text(
                'New habit',
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
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/planner_page_icons/planner_habit_icon.svg',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
          ),
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

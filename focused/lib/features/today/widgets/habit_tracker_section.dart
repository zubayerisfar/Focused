import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../habits/models/habit.dart';
import '../../habits/providers/habit_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/widgets/glass_container.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = habits
        .where((habit) => provider.isCompletedForDate(habit, date))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/today_screen_icons/habit_icon_today_screen.svg',
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
                "Today's Habit Tracker",
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (habits.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$completed/${habits.length}',
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (habits.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(22),
            child: Center(
              child: Text(
                'No habits scheduled today.',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final complete = provider.isCompletedForDate(habit, date);
    final progress = provider.progressForDate(habit.id, date);
    final progressText = habit.goalType == HabitGoalType.checkIn
        ? (complete ? 'Completed' : 'Tap to complete')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push('/habit/${Uri.encodeComponent(habit.id)}'),
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
                    fontFamily: 'Quicksand',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: complete ? TextDecoration.lineThrough : null,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  progressText,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: complete ? 'Undo' : 'Complete',
            onPressed: () async {
              final willComplete = !complete;
              await provider.toggleCompleted(habit.id, date);
              if (willComplete && context.mounted) {
                final stats = context.read<UserStatsProvider>();
                await stats.addGems(UserStatsProvider.gemHabitReward);
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
            icon: Icon(
              complete ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: complete
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white38 : Colors.black26),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

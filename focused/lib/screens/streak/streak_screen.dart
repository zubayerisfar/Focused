import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/achievement_badge.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/streak_goal_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/achievement_service.dart';
import '../../services/productivity_streak_service.dart';
import '../../widgets/achievement_badge_art.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  static const _streakService = ProductivityStreakService();
  static const _achievementService = AchievementService();

  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final habits = context.watch<HabitProvider>();
    final goal = context.watch<StreakGoalProvider>();
    final userStats = context.watch<UserStatsProvider>();
    final now = DateTime.now();

    final activityDates = <DateTime>{
      ...tasks.completionActivityDates(),
      ...focus.focusActivityDates(),
      ...habits.habitCompletionDates(),
    };
    final normalizedActivity = activityDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    final localCurrent = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
    );
    final localLongest = _streakService.calculateLongestStreak(
      activityDates: activityDates,
    );
    final current = math.max(localCurrent, userStats.syncedStreakDays);
    final longest = math.max(
      math.max(localLongest, userStats.syncedLongestStreak),
      current,
    );

    final localTotalFocus = focus.totalStoredFocusDuration;
    final effectiveTotalFocus = localTotalFocus > userStats.syncedFocusDuration
        ? localTotalFocus
        : userStats.syncedFocusDuration;

    final badges = _achievementService.buildBadges(
      longestStreak: longest,
      longestLinkedTaskSession: focus.longestLinkedTaskSessionFocusDuration,
      totalFocus: effectiveTotalFocus,
      unlockedBadgeIds: userStats.unlockedBadgeIds,
    );
    final streakBadges = badges
        .where((badge) => badge.category == AchievementBadgeCategory.streak)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak'),
        actions: [
          IconButton(
            tooltip: 'All badges',
            onPressed: () => context.push('/badges'),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          _StreakHero(current: current, longest: longest),
          const SizedBox(height: 24),
          _MonthCalendar(
            month: _visibleMonth,
            activeDays: normalizedActivity,
            onPrevious: () => setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
              );
            }),
            onNext: () => setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
              );
            }),
          ),
          const SizedBox(height: 26),
          _GoalCard(
            current: current,
            goalDays: goal.goalDays,
            onChangeGoal: () => _chooseGoal(context),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Streak badges',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/badges'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: streakBadges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final badge = streakBadges[index];
                return _StreakBadgeCard(badge: badge);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseGoal(BuildContext context) async {
    final provider = context.read<StreakGoalProvider>();
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your streak goal',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: StreakGoalProvider.allowedGoals
                      .map((days) {
                        final selected = days == provider.goalDays;
                        return ChoiceChip(
                          label: Text('$days days'),
                          selected: selected,
                          onSelected: (_) => Navigator.pop(sheetContext, days),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && context.mounted) {
      await provider.setGoalDays(selected);
    }
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$current',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF7A45),
                  ),
                ),
                Text(
                  'day streak',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Best: $longest days',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFD600), Color(0xFFFF7043)],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  color: const Color(0xFFFF8A3D).withOpacity(0.28),
                ),
              ],
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 58)),
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.activeDays,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final Set<DateTime> activeDays;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 7),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(month.year, month.month, day);
              final active = activeDays.contains(date);
              final today = _sameDate(date, DateTime.now());

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? const Color(0xFFFFA629)
                      : today
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  border: today && !active
                      ? Border.all(color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active || today
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: active
                        ? Colors.black87
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.current,
    required this.goalDays,
    required this.onChangeGoal,
  });

  final int current;
  final int goalDays;
  final VoidCallback onChangeGoal;

  @override
  Widget build(BuildContext context) {
    final progress = (current / goalDays).clamp(0.0, 1.0).toDouble();
    final remaining = (goalDays - current).clamp(0, goalDays);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Streak goal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onChangeGoal, child: const Text('Change')),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            current >= goalDays
                ? 'Goal reached — keep the streak alive.'
                : '$current / $goalDays days • $remaining to go',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadgeCard extends StatelessWidget {
  const _StreakBadgeCard({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: Column(
        children: [
          AchievementBadgeArt(badge: badge, size: 88),
          const SizedBox(height: 7),
          Text(
            badge.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: badge.achieved ? FontWeight.w700 : FontWeight.w500,
              color: badge.achieved
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

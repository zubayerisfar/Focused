import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task.dart';
import '../providers/app_limit_provider.dart';
import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../providers/usage_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../streak/services/achievement_service.dart';
import '../../../core/services/home_widget_service.dart';
import '../../streak/services/productivity_streak_service.dart';
import '../../../core/theme/app_theme.dart';

class LifestyleSummaryCard extends StatelessWidget {
  const LifestyleSummaryCard({super.key});

  static const _streakService = ProductivityStreakService();
  static const _achievementService = AchievementService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final usage = context.watch<UsageProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final limitProvider = context.watch<AppLimitProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();

    final now = DateTime.now();

    final activityDates = <DateTime>{
      ...taskProvider.completionActivityDates(),
      ...focusProvider.focusActivityDates(),
      ...habitProvider.habitCompletionDates(),
    };
    final localStreak = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
    );
    final streak = math.max(localStreak, userStats.syncedStreakDays);

    final localTotalFocus = focusProvider.totalStoredFocusDuration;
    final effectiveTotalFocus = localTotalFocus > userStats.syncedFocusDuration
        ? localTotalFocus
        : userStats.syncedFocusDuration;
    final totalFocusHours = effectiveTotalFocus.inSeconds / 3600.0;

    final longest = _streakService.calculateLongestStreak(
      activityDates: activityDates,
    );
    final effectiveLongest = math.max(
      math.max(longest, userStats.syncedLongestStreak),
      streak,
    );
    final badges = _achievementService.buildBadges(
      longestStreak: effectiveLongest,
      longestLinkedTaskSession:
          focusProvider.longestLinkedTaskSessionFocusDuration,
      totalFocus: effectiveTotalFocus,
      unlockedBadgeIds: userStats.unlockedBadgeIds,
    );
    final unlockedBadgesCount = badges.where((b) => b.achieved).length;

    final todayTasks = taskProvider.tasksForDate(now, includeCompleted: false);
    final completedTasks = taskProvider
        .tasksForDate(now, includeCompleted: true)
        .where((t) => taskProvider.isTaskCompletedForDate(t, now))
        .length;
    final totalTodayTasks = todayTasks.length + completedTasks;

    final todayUsage = usage.todaySummary?.totalUsage ?? Duration.zero;
    final yesterdayUsage = usage.yesterdaySummary?.totalUsage;

    // Calculate percentage change vs yesterday
    String comparisonText = 'Tracking your daily rhythm';
    Color comparisonColor = scheme.onSurfaceVariant;
    IconData comparisonIcon = Icons.auto_awesome_rounded;

    if (yesterdayUsage != null && yesterdayUsage.inMinutes > 0) {
      final diff = todayUsage.inMinutes - yesterdayUsage.inMinutes;
      final percent = ((diff / yesterdayUsage.inMinutes) * 100).round();

      if (percent < -3) {
        final absPercent = percent.abs();
        comparisonText = '$absPercent% less screen time than yesterday';
        comparisonColor = const Color(0xFF10B981);
        comparisonIcon = Icons.trending_down_rounded;
      } else if (percent > 3) {
        comparisonText = '$percent% more screen time than yesterday';
        comparisonColor = const Color(0xFFF59E0B);
        comparisonIcon = Icons.trending_up_rounded;
      } else {
        comparisonText = 'About the same screen time as yesterday';
        comparisonColor = AppTheme.primaryBlue;
        comparisonIcon = Icons.trending_flat_rounded;
      }
    }

    final activeLimits = limitProvider.limits
        .where((l) => l.isEnabled)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskItems = todayTasks.take(3).map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'isDone': taskProvider.isTaskCompletedForDate(t, now),
        };
      }).toList();

      final focusHoursStr = totalFocusHours.toStringAsFixed(
        totalFocusHours % 1 == 0 ? 0 : 1,
      );

      HomeWidgetService.updateWidgetData(
        screenTimeFormatted: _formatDuration(todayUsage),
        comparisonText: comparisonText,
        streakText: '🔥 $streak d streak',
        focusHoursText: '⏱️ ${focusHoursStr}h focused',
        tasks: taskItems,
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Screen Time & % vs Yesterday
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Lifestyle Pulse",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDuration(todayUsage),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activeLimits.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/wellbeing/limits'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${activeLimits.length} limits',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(comparisonIcon, size: 16, color: comparisonColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comparisonText,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: comparisonColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push('/streak'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF6B5E,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$streak d streak',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B5E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push('/focus/history'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${totalFocusHours.toStringAsFixed(totalFocusHours % 1 == 0 ? 0 : 1)}h focus',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push('/profile/badges'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏅', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$unlockedBadgesCount badges',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Today's Planned Tasks Overview
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Today’s Plan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalTodayTasks > 0
                          ? '$completedTasks of $totalTodayTasks done'
                          : 'No tasks scheduled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (todayTasks.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: completedTasks > 0
                              ? const Color(0xFF10B981)
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            completedTasks > 0
                                ? 'All planned tasks completed today! 🎉'
                                : 'Plan your first task to start focusing.',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...todayTasks
                      .take(2)
                      .map(
                        (task) => _MiniTaskRow(
                          task: task,
                          now: now,
                          onToggle: () async {
                            await taskProvider.setCompletedForDate(
                              task.id,
                              now,
                              true,
                            );
                          },
                        ),
                      ),
                ],
                const SizedBox(height: 14),
                // Quick Focus Start Action
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (todayTasks.isNotEmpty) {
                            final topTask = todayTasks.first;
                            final occurrence = taskProvider
                                .occurrenceForTaskOnDate(topTask, now);
                            final taskId = Uri.encodeComponent(topTask.id);
                            final occDate = occurrence != null
                                ? '&occurrenceDate=${occurrence.start.year}-${occurrence.start.month.toString().padLeft(2, '0')}-${occurrence.start.day.toString().padLeft(2, '0')}'
                                : '';
                            context.push('/focus/setup?taskId=$taskId$occDate');
                          } else {
                            context.push('/focus/setup');
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          todayTasks.isNotEmpty
                              ? 'Focus: ${todayTasks.first.title}'
                              : 'Start Focus Session',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return '0m screen time';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m screen time';
    if (mins == 0) return '${hours}h screen time';
    return '${hours}h ${mins}m screen time';
  }
}

class _MiniTaskRow extends StatelessWidget {
  const _MiniTaskRow({
    required this.task,
    required this.now,
    required this.onToggle,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _priorityColor(task.priority),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.scheduledStart != null) ...[
              const SizedBox(width: 6),
              Text(
                '${task.scheduledStart!.hour.toString().padLeft(2, '0')}:${task.scheduledStart!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.critical:
        return const Color(0xFFFF6B5E);
      case TaskPriority.important:
        return AppTheme.primaryBlue;
      case TaskPriority.growth:
        return const Color(0xFF34B27B);
    }
  }
}

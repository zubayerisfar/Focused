import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../wellbeing/providers/usage_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/widgets/profile_streak_xp_bar.dart';
import '../../streak/services/productivity_streak_service.dart';
import '../widgets/daily_overview_card.dart';
import '../widgets/daily_plan_section.dart';
import '../widgets/habit_tracker_section.dart';
import '../widgets/next_today_task.dart';
import '../widgets/productivity_insight_card.dart';
import '../widgets/task_mates_section.dart';
import '../widgets/today_reminders_section.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _streakService = ProductivityStreakService();

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final usageProvider = context.watch<UsageProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();

    final now = DateTime.now();
    final schedule = taskProvider.scheduledOccurrencesForDate(now);
    final todayTasks = taskProvider.tasksForDate(now, includeCompleted: false);
    final habits = habitProvider.habitsForDate(now);

    final next = findNextTodayTask(
      taskProvider: taskProvider,
      schedule: schedule,
      todayTasks: todayTasks,
      now: now,
    );

    final activityDates = <DateTime>{
      ...taskProvider.completionActivityDates(),
      ...focusProvider.focusActivityDates(),
      ...habitProvider.habitCompletionDates(),
    };
    final streakDetails = _streakService.evaluateStreakDetails(
      now: now,
      activityDates: activityDates,
      restoredDates: userStats.parsedRestoredStreakDates,
      debugForceDanger: userStats.debugSimulateStreakInDanger,
    );
    final isInDanger = streakDetails.isInDanger;
    final streak = math.max(
      streakDetails.currentStreak,
      userStats.syncedStreakDays,
    );

    final localFocus = focusProvider.totalStoredFocusDuration;
    final effectiveFocus = localFocus > userStats.syncedFocusDuration
        ? localFocus
        : userStats.syncedFocusDuration;
    final focusHours = effectiveFocus.inSeconds / 3600.0;
    final focusHoursStr = focusHours.toStringAsFixed(
      focusHours % 1 == 0 ? 0 : 1,
    );

    final todayUsage = usageProvider.todaySummary?.totalUsage ?? Duration.zero;
    String comparisonText = 'Tracking your daily rhythm';
    if (usageProvider.todayVsYesterdayPercent != null) {
      final percent = usageProvider.todayVsYesterdayPercent!;
      if (percent.abs() < 0.5) {
        comparisonText = 'About the same screen time as yesterday';
      } else if (percent < 0) {
        comparisonText =
            '📉 ${percent.abs().round()}% less screen time than yesterday';
      } else {
        comparisonText =
            '📈 ${percent.round()}% more screen time than yesterday';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskItems = todayTasks.take(3).map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'isDone': taskProvider.isTaskCompletedForDate(t, now),
        };
      }).toList();

      HomeWidgetService.updateWidgetData(
        screenTimeFormatted: _formatDuration(todayUsage),
        comparisonText: comparisonText,
        streakText: '🔥 $streak d streak',
        focusHoursText: '⏱️ ${focusHoursStr}h focused',
        tasks: taskItems,
      );
    });

    final completedTasks = taskProvider
        .tasksForDate(now, includeCompleted: true)
        .where((t) => taskProvider.isTaskCompletedForDate(t, now))
        .length;
    final totalTodayTasks = todayTasks.length + completedTasks;

    final focusedToday = focusProvider.focusedDurationForDate(now);
    final yesterday = now.subtract(const Duration(days: 1));
    final focusedYesterday = focusProvider.focusedDurationForDate(yesterday);

    double? focusComparisonPercent;
    if (focusedYesterday.inMinutes > 0) {
      final diff = focusedToday.inMinutes - focusedYesterday.inMinutes;
      focusComparisonPercent = (diff / focusedYesterday.inMinutes) * 100.0;
    } else if (focusedToday.inMinutes > 0) {
      focusComparisonPercent = 100.0;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 54,
        titleSpacing: 18,
        title: Text(
          'Home',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: const [
          ProfileStreakXpBar(showProfile: true, avatarRadius: 20),
          SizedBox(width: 18),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => usageProvider.refreshPermissionAndUsage(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isInDanger) ...[
                    _StreakDangerBanner(
                      streak: streak,
                      onRestoreTap: () =>
                          Navigator.of(context).pushNamed('/streak'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DailyOverviewCard(
                    focusedToday: focusedToday,
                    focusComparisonPercent: focusComparisonPercent,
                    usageToday: usageProvider.todaySummary?.totalUsage,
                    comparisonPercent: usageProvider.todayVsYesterdayPercent,
                    topApps: usageProvider.topAppEntriesToday(limit: 3),
                    usageConnected: usageProvider.hasUsageAccess,
                  ),
                  const SizedBox(height: 24),
                  DailyPlanSection(
                    next: next,
                    date: now,
                    completedTasksCount: completedTasks,
                    totalTasksCount: totalTodayTasks,
                  ),
                  const SizedBox(height: 24),
                  TaskMatesSection(date: now),
                  const SizedBox(height: 24),
                  TodayRemindersSection(date: now),
                  const SizedBox(height: 32),
                  HabitTrackerSection(habits: habits, date: now),
                  const SizedBox(height: 24),
                  const ProductivityInsightCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

class _StreakDangerBanner extends StatelessWidget {
  final int streak;
  final VoidCallback onRestoreTap;

  const _StreakDangerBanner({required this.streak, required this.onRestoreTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚠️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Streak in Danger! ($streak d)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Missed yesterday! 1-day grace period ends at 11:59 PM.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.push('/streak'),
            child: const Text(
              'Restore',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

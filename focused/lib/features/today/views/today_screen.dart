import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/account_provider.dart';
import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../wellbeing/providers/usage_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/home_widget_service.dart';
import '../../streak/services/productivity_streak_service.dart';
import '../widgets/daily_overview_card.dart';
import '../widgets/daily_plan_section.dart';
import '../widgets/habit_tracker_section.dart';
import '../widgets/home_header.dart';
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
    final account = context.watch<AccountProvider>();

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
    final localStreak = _streakService.calculateCurrentStreak(
      now: now,
      activityDates: activityDates,
    );
    final streak = math.max(localStreak, userStats.syncedStreakDays);

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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => usageProvider.refreshPermissionAndUsage(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HomeHeader(
                streak: streak,
                photoUrl: account.photoUrl,
                displayName: account.displayName,
                xpPoints: userStats.xpPoints,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  DailyOverviewCard(
                    focusedToday: focusedToday,
                    focusComparisonPercent: focusComparisonPercent,
                    usageToday: usageProvider.todaySummary?.totalUsage,
                    comparisonPercent: usageProvider.todayVsYesterdayPercent,
                    topApps: usageProvider.topAppEntriesToday(limit: 3),
                    usageConnected: usageProvider.hasUsageAccess,
                  ),
                  const SizedBox(height: 24),
                  const ProductivityInsightCard(),
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

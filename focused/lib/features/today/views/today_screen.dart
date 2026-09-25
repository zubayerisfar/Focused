import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/account_provider.dart';
import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/profile_streak_gem_bar.dart';
import 'package:go_router/go_router.dart';
import '../../streak/services/productivity_streak_service.dart';
import '../widgets/daily_plan_section.dart';
import '../widgets/habit_tracker_section.dart';
import '../widgets/motivational_hero_banner.dart';
import '../widgets/next_today_task.dart';
import '../widgets/task_mates_section.dart';
import '../widgets/today_reminders_section.dart';
import '../widgets/two_part_focus_task_section.dart';
import '../widgets/weekly_date_strip.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _streakService = ProductivityStreakService();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final userStats = context.watch<UserStatsProvider>();
    final account = context.watch<AccountProvider>();

    final now = DateTime.now();
    final activeDate = _selectedDate;
    final schedule = taskProvider.scheduledOccurrencesForDate(activeDate);
    final todayTasks = taskProvider.tasksForDate(
      activeDate,
      includeCompleted: false,
    );
    final habits = habitProvider.habitsForDate(activeDate);

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

    final completedTasks = taskProvider
        .tasksForDate(activeDate, includeCompleted: true)
        .where((t) => taskProvider.isTaskCompletedForDate(t, activeDate))
        .length;
    final totalTodayTasks = todayTasks.length + completedTasks;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskItems = todayTasks.take(3).map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'isDone': taskProvider.isTaskCompletedForDate(t, activeDate),
        };
      }).toList();

      HomeWidgetService.updateWidgetData(
        screenTimeFormatted: '${focusHoursStr}h focused',
        comparisonText: 'Productive and in rhythm',
        streakText: '🔥 $streak d streak',
        focusHoursText: '⏱️ ${focusHoursStr}h focused',
        tasks: taskItems,
      );
    });

    final focusedToday = focusProvider.focusedDurationForDate(activeDate);

    final userName = account.displayName.trim().isNotEmpty
        ? account.displayName.trim().split(' ').first
        : 'User';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hello, $userName 👋',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, d MMMM').format(activeDate),
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: const [
          ProfileStreakGemBar(showProfile: true, avatarRadius: 20),
          SizedBox(width: 18),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (isInDanger) ...[
                    _StreakDangerBanner(
                      streak: streak,
                      onRestoreTap: () => context.push('/streak'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Motivational Start Strong Hero Card
                  MotivationalHeroBanner(pendingTasks: todayTasks.length),
                  const SizedBox(height: 16),

                  // Weekly Date Strip Selector
                  WeeklyDateStrip(
                    selectedDate: _selectedDate,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Two-Part Priority Tasks & Focus Split Section (TaskityAI layout)
                  TwoPartFocusTaskSection(
                    tasks: todayTasks,
                    date: activeDate,
                    focusedToday: focusedToday,
                    focusSessionsCount: focusProvider
                        .sessionsForDate(activeDate)
                        .length,
                    completedTasksCount: completedTasks,
                    totalTasksCount: totalTodayTasks,
                    onAddTask: () =>
                        context.push('/task/new?priority=critical'),
                  ),
                  const SizedBox(height: 24),

                  // Daily Plan / Schedule
                  DailyPlanSection(
                    next: next,
                    date: activeDate,
                    completedTasksCount: completedTasks,
                    totalTasksCount: totalTodayTasks,
                  ),
                  const SizedBox(height: 24),

                  // Squads & Task Mates
                  TaskMatesSection(date: activeDate),
                  const SizedBox(height: 24),

                  // Reminders Section
                  TodayRemindersSection(date: activeDate),
                  const SizedBox(height: 32),

                  // Habit Tracker Section
                  HabitTrackerSection(habits: habits, date: activeDate),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakDangerBanner extends StatelessWidget {
  final int streak;
  final VoidCallback onRestoreTap;

  const _StreakDangerBanner({required this.streak, required this.onRestoreTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      onTap: onRestoreTap,
      color: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2),
      border: Border.all(
        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
        width: 1.5,
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
                      'Streak at Risk!',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '🔥 $streak d',
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Restore with Gems or complete a task today.',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: onRestoreTap,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_usage_app_entry.dart';
import '../../models/habit.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_mate_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/usage_provider.dart';
import '../../providers/user_stats_provider.dart';
import '../../services/ad_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/productivity_streak_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

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

    final next = _findNextTodayTask(
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
              child: _HomeHeader(
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
                  _DailyOverviewCard(
                    focusedToday: focusedToday,
                    focusComparisonPercent: focusComparisonPercent,
                    usageToday: usageProvider.todaySummary?.totalUsage,
                    comparisonPercent: usageProvider.todayVsYesterdayPercent,
                    topApps: usageProvider.topAppEntriesToday(limit: 3),
                    usageConnected: usageProvider.hasUsageAccess,
                  ),
                  const SizedBox(height: 24),
                  const _ProductivityInsightCard(),
                  const SizedBox(height: 24),
                  _DailyPlanSection(
                    next: next,
                    date: now,
                    completedTasksCount: completedTasks,
                    totalTasksCount: totalTodayTasks,
                  ),
                  const SizedBox(height: 24),
                  _TodayRemindersSection(date: now),
                  const SizedBox(height: 32),
                  _HabitTrackerSection(habits: habits, date: now),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int streak;
  final String? photoUrl;
  final String displayName;
  final int xpPoints;

  const _HomeHeader({
    required this.streak,
    required this.photoUrl,
    required this.displayName,
    required this.xpPoints,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Home',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            // XP chip
            InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => context.push('/xp'),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1CB0F6,
                  ).withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: const Color(0xFF1CB0F6).withValues(alpha: 0.32),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: Color(0xFF1CB0F6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$xpPoints',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1CB0F6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Streak chip
            InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => context.push('/streak'),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFFF9600,
                  ).withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: const Color(0xFFFF9600).withValues(alpha: 0.32),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 16, height: 1.0),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF9600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Text(
                        _initials(displayName),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyOverviewCard extends StatelessWidget {
  final Duration focusedToday;
  final double? focusComparisonPercent;
  final Duration? usageToday;
  final double? comparisonPercent;
  final List<AppUsageAppEntry> topApps;
  final bool usageConnected;

  const _DailyOverviewCard({
    required this.focusedToday,
    required this.focusComparisonPercent,
    required this.usageToday,
    required this.comparisonPercent,
    required this.topApps,
    required this.usageConnected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today at a glance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _OverviewMetricCard(
                    title: 'Focused',
                    value: _formatDuration(focusedToday),
                    customIcon: SvgPicture.asset(
                      'assets/icon/focus_icon.svg',
                      width: 34,
                      height: 34,
                    ),
                    accent: const Color(0xFFFF5B5B),
                    trendPercent: focusComparisonPercent,
                    isHigherBetter: true,
                    onTap: () => _showFocusAnalysisSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OverviewMetricCard(
                    title: 'App Usage',
                    value: usageToday == null
                        ? (usageConnected ? 'No data' : 'Connect')
                        : _formatDuration(usageToday!),
                    customIcon: SvgPicture.asset(
                      'assets/icon/app_usage_icon.svg',
                      width: 34,
                      height: 34,
                    ),
                    accent: const Color(0xFF6C5CE7),
                    trendPercent: usageToday == null ? null : comparisonPercent,
                    isHigherBetter: false,
                    onTap: () => context.push('/wellbeing'),
                  ),
                ),
              ],
            ),
          ),
          if (topApps.isNotEmpty) ...[
            const SizedBox(height: 22),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Most used apps',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Top apps today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _TopAppsCompactList(
              entries: topApps.take(4).toList(growable: false),
              onOpenApp: (entry) {
                final id = Uri.encodeComponent(entry.appId);
                final name = Uri.encodeQueryComponent(entry.appName);
                context.push('/wellbeing/app/$id?name=$name');
              },
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => context.push('/focus/setup'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text(
                'Start Focus Session',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFocusAnalysisSheet(BuildContext context) {
    final focusProvider = context.read<FocusProvider>();
    final now = DateTime.now();
    final todayDuration = focusProvider.focusedDurationForDate(now);
    final todaySessions = focusProvider.sessionsForDate(now);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: theme.dividerColor),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
            top: 14,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B5B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFFFF5B5B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Focus Analysis',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(bottomSheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (todaySessions.isEmpty || todayDuration.inMinutes == 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 52,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No focus information available for now',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a focus session today to analyze your productivity blocks, flow rate, and deep work time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF5B5B,
                          ).withValues(alpha: isDark ? 0.16 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFFF5B5B,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Focused',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(todayDuration),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF5B5B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1CB0F6,
                          ).withValues(alpha: isDark ? 0.16 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFF1CB0F6,
                            ).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sessions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${todaySessions.length}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1CB0F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Today's Sessions",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: todaySessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final session = todaySessions[index];
                      final duration = session.actualFocusDuration;
                      final name = session.taskName.trim().isEmpty
                          ? 'Quick Focus'
                          : session.taskName;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.35,
                                )
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: Color(0xFFFF5B5B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(bottomSheetContext).pop();
                  context.push('/focus/setup');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Start Focus Session',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Widget? customIcon;
  final Color accent;
  final double? trendPercent;
  final bool isHigherBetter;
  final VoidCallback? onTap;

  const _OverviewMetricCard({
    required this.title,
    required this.value,
    this.icon,
    this.customIcon,
    required this.accent,
    this.trendPercent,
    this.isHigherBetter = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trend = trendPercent;
    final isClickable = onTap != null;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isClickable
            ? (isDark
                  ? scheme.surfaceContainerHigh
                  : accent.withValues(alpha: 0.05))
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClickable
              ? accent.withValues(alpha: isDark ? 0.35 : 0.28)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isClickable ? 1.5 : 1.0,
        ),
        boxShadow: isClickable
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isClickable) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: accent.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (customIcon != null)
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(child: customIcon),
                )
              else if (icon != null)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Icon(icon, size: 26, color: accent),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (trend != null) ...[
                      const SizedBox(height: 4),
                      _TrendText(value: trend, isHigherBetter: isHigherBetter),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withValues(alpha: 0.15),
        highlightColor: accent.withValues(alpha: 0.08),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _TrendText extends StatelessWidget {
  final double value;
  final bool isHigherBetter;

  const _TrendText({required this.value, this.isHigherBetter = false});

  @override
  Widget build(BuildContext context) {
    final down = value < 0;
    final flat = value.abs() < 0.5;

    final isPositive = isHigherBetter ? !down : down;
    final color = flat
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : isPositive
        ? AppTheme.success
        : AppTheme.danger;

    final icon = flat
        ? Icons.remove_rounded
        : down
        ? Icons.south_east_rounded
        : Icons.north_east_rounded;

    final statusText = flat
        ? '0% change'
        : '${value.abs().round()}% ${down ? 'less' : 'more'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          'vs yesterday',
          style: TextStyle(
            fontSize: 10.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TopAppsCompactList extends StatelessWidget {
  const _TopAppsCompactList({required this.entries, required this.onOpenApp});

  final List<AppUsageAppEntry> entries;
  final ValueChanged<AppUsageAppEntry> onOpenApp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final isLast = index == entries.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: AppIcon(
                  iconBytes: entry.iconBytes,
                  appName: entry.appName,
                  size: 38,
                ),
                title: Text(
                  entry.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(entry.duration),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.outline,
                    ),
                  ],
                ),
                onTap: () => onOpenApp(entry),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DailyPlanSection extends StatelessWidget {
  final _NextTodayTask? next;
  final DateTime date;
  final int completedTasksCount;
  final int totalTasksCount;

  const _DailyPlanSection({
    required this.next,
    required this.date,
    required this.completedTasksCount,
    required this.totalTasksCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allDone =
        totalTasksCount > 0 && completedTasksCount == totalTasksCount;
    final progressLabel = totalTasksCount == 0
        ? 'No tasks planned'
        : (allDone
              ? 'All $totalTasksCount done 🎉'
              : '$completedTasksCount of $totalTasksCount done');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        next == null ? 'Overview' : 'Next task',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: allDone
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          progressLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: allDone
                                ? const Color(0xFF10B981)
                                : scheme.onSurfaceVariant,
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
        const SizedBox(height: 12),
        if (next == null)
          _EmptyPlanCard(date: date)
        else
          _NextTaskCard(next: next!),
        const SizedBox(height: 10),
        const _TaskMatesSummaryCard(),
      ],
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  final _NextTodayTask next;

  const _NextTaskCard({required this.next});

  @override
  Widget build(BuildContext context) {
    final task = next.task;
    final isSquad = task.isSquadTask;
    const squadColor = Color(0xFF2563EB); // Calming royal oceanic blue
    final color = isSquad ? squadColor : _priorityColor(task.priority);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(
          '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(next.date)}',
        ),
        onLongPress: () =>
            context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 58,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isSquad) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: squadColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_rounded,
                                  size: 13,
                                  color: squadColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Squad',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: squadColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      next.occurrence == null
                          ? 'Anytime today'
                          : '${DateFormat('h:mm a').format(next.occurrence!.start)} – ${DateFormat('h:mm a').format(next.occurrence!.end)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Start focus',
                onPressed: () => context.push(
                  '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}&occurrenceDate=${_dateQuery(next.date)}',
                ),
                icon: SvgPicture.asset(
                  'assets/icon/focus_icon.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  final DateTime date;

  const _EmptyPlanCard({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No unfinished tasks for ${DateFormat('EEEE').format(date)}.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitTrackerSection extends StatelessWidget {
  final List<Habit> habits;
  final DateTime date;

  const _HabitTrackerSection({required this.habits, required this.date});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final completed = habits
        .where((habit) => provider.isCompletedForDate(habit, date))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fact_check_outlined, size: 22, color: AppTheme.lavender),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Today's habit tracker",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (habits.isNotEmpty)
              Text(
                '$completed/${habits.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (habits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              'No habits scheduled today.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final complete = provider.isCompletedForDate(habit, date);
    final progress = provider.progressForDate(habit.id, date);
    final progressText = habit.goalType == HabitGoalType.checkIn
        ? (complete ? 'Completed' : 'Tap to complete')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/habit/${Uri.encodeComponent(habit.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: complete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progressText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () => provider.toggleCompleted(habit.id, date),
                icon: Icon(
                  complete ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: complete ? habit.color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextTodayTask {
  final Task task;
  final TaskOccurrence? occurrence;
  final DateTime date;

  const _NextTodayTask({
    required this.task,
    required this.occurrence,
    required this.date,
  });
}

_NextTodayTask? _findNextTodayTask({
  required TaskProvider taskProvider,
  required List<TaskOccurrence> schedule,
  required List<Task> todayTasks,
  required DateTime now,
}) {
  final day = DateTime(now.year, now.month, now.day);

  final scheduled =
      schedule.where((occurrence) => !occurrence.isCompleted).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  if (scheduled.isNotEmpty) {
    final future = scheduled.where((occurrence) => occurrence.end.isAfter(now));
    final occurrence = future.isNotEmpty ? future.first : scheduled.first;
    return _NextTodayTask(
      task: occurrence.task,
      occurrence: occurrence,
      date: day,
    );
  }

  final unscheduled = todayTasks
      .where((task) => task.scheduledStart == null)
      .toList();
  if (unscheduled.isEmpty) return null;

  unscheduled.sort(
    (a, b) => a.priority.sortOrder.compareTo(b.priority.sortOrder),
  );
  return _NextTodayTask(task: unscheduled.first, occurrence: null, date: day);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return AppTheme.danger;
    case TaskPriority.important:
      return AppTheme.primaryBlue;
    case TaskPriority.growth:
      return AppTheme.success;
  }
}

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _TodayRemindersSection extends StatelessWidget {
  final DateTime date;

  const _TodayRemindersSection({required this.date});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allReminders = taskProvider.tasks
        .where((t) => t.reminderMinutesBefore != null)
        .toList();

    final dateReminders = allReminders.where((t) {
      if (t.scheduledStart != null) {
        return _sameDate(t.scheduledStart!, date);
      }
      if (t.plannedDate != null) {
        return _sameDate(t.plannedDate!, date);
      }
      return false;
    }).toList();

    final activeReminders =
        (dateReminders.isNotEmpty ? dateReminders : allReminders)
            .where((t) => !t.isCompleted)
            .take(3)
            .toList();

    const accent = Color(0xFFFF9600);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 22,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reminders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (activeReminders.isNotEmpty)
              Text(
                '${activeReminders.length} active',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeReminders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active reminders for today.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          ...activeReminders.map(
            (reminder) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push(
                    '/reminder/edit/${Uri.encodeComponent(reminder.id)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
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
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
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
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Done',
                          onPressed: () =>
                              taskProvider.setCompleted(reminder.id, true),
                          icon: const Icon(Icons.circle_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TaskMatesSummaryCard extends StatelessWidget {
  const _TaskMatesSummaryCard();

  @override
  Widget build(BuildContext context) {
    final taskMateProvider = context.watch<TaskMateProvider>();
    final groups = taskMateProvider.groups;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeGroups = groups.where((g) => g.activeTasks.isNotEmpty).toList();
    if (activeGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstGroup = activeGroups.first;
    final activeTaskCount = activeGroups.fold<int>(
      0,
      (sum, g) => sum + g.activeTasks.length,
    );

    // Eye-smoothing calm oceanic blue/indigo palette
    const squadColor = Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? squadColor.withValues(alpha: 0.35)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/friends?tab=squads'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A) : squadColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SvgPicture.asset(
                'assets/icon/group_task.svg',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Task Mates Squad',
                        style: TextStyle(
                          color: isDark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? squadColor.withValues(alpha: 0.35)
                              : squadColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$activeTaskCount active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : squadColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${firstGroup.name}: "${firstGroup.activeTasks.first.title}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: isDark ? const Color(0xFF93C5FD) : squadColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductivityInsightCard extends StatefulWidget {
  const _ProductivityInsightCard();

  @override
  State<_ProductivityInsightCard> createState() =>
      _ProductivityInsightCardState();
}

class _ProductivityInsightCardState extends State<_ProductivityInsightCard> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _unlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productivity Insight',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : scheme.onSurface,
                ),
              ),
              if (_unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Unlocked',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_unlocked)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1CB0F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  AdService.instance.showRewardedAd(
                    onUserEarnedReward: (reward) {
                      if (mounted) {
                        setState(() => _unlocked = true);
                        _openDetailedReport(context);
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text(
                  'Watch ad to unlock insight',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openDetailedReport(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Peak Focus: 9:00 AM – 11:30 AM',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF58CC02,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '87% Focus',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF58CC02),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildVelocityBar('8a', 0.45, false, isDark, scheme),
                        _buildVelocityBar('9a', 0.88, false, isDark, scheme),
                        _buildVelocityBar('10a', 0.96, true, isDark, scheme),
                        _buildVelocityBar('11a', 0.82, false, isDark, scheme),
                        _buildVelocityBar('12p', 0.35, false, isDark, scheme),
                        _buildVelocityBar('2p', 0.60, false, isDark, scheme),
                        _buildVelocityBar('4p', 0.72, false, isDark, scheme),
                        _buildVelocityBar('8p', 0.40, false, isDark, scheme),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetailedReport(BuildContext context) {
    context.push('/wellbeing/focus-interruptions');
  }

  Widget _buildVelocityBar(
    String label,
    double heightPercent,
    bool isPeak,
    bool isDark,
    ColorScheme scheme,
  ) {
    const double maxHeight = 46.0;
    final barHeight = maxHeight * heightPercent;
    final color = isPeak
        ? const Color(0xFFFF9600)
        : (heightPercent >= 0.7
              ? const Color(0xFF1CB0F6)
              : const Color(0xFF9E9E9E).withValues(alpha: 0.4));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPeak)
          const Text(
            '★',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFFFF9600),
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const SizedBox(height: 12),
        Container(
          width: 20,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w500,
            color: isPeak
                ? (isDark ? Colors.white : Colors.black)
                : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/daily_usage_metrics.dart';
import '../../focus/models/focus_analysis_coverage.dart';
import '../../focus/models/focus_session.dart';
import '../../habits/models/habit_period_summary.dart';
import '../../tasks/models/task_execution_period_summary.dart';
import '../models/usage_data_coverage.dart';
import '../models/usage_data_provenance.dart';
import '../../focus/providers/focus_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../providers/usage_provider.dart';
import '../../tasks/services/task_execution_analyzer.dart';

class WeeklyWellbeingScreen extends StatefulWidget {
  const WeeklyWellbeingScreen({super.key});

  @override
  State<WeeklyWellbeingScreen> createState() => _WeeklyWellbeingScreenState();
}

class _WeeklyWellbeingScreenState extends State<WeeklyWellbeingScreen> {
  static const _executionAnalyzer = TaskExecutionAnalyzer();

  late DateTime _endDay;
  late Future<List<DailyUsageMetrics>> _future;

  @override
  void initState() {
    super.initState();
    _endDay = _dateOnly(DateTime.now());
    _future = _load();
  }

  Future<List<DailyUsageMetrics>> _load() {
    return context.read<UsageProvider>().loadDailyUsageHistory(
          days: 14,
          endDay: _endDay,
        );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _earlier() {
    setState(() {
      _endDay = DateTime(_endDay.year, _endDay.month, _endDay.day - 7);
      _future = _load();
    });
  }

  void _newer() {
    final today = _dateOnly(DateTime.now());
    final candidate = DateTime(_endDay.year, _endDay.month, _endDay.day + 7);
    setState(() {
      _endDay = candidate.isAfter(today) ? today : candidate;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final habitProvider = context.watch<HabitProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final today = _dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '7-day summary',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<DailyUsageMetrics>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _AnalyticsError(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final all = snapshot.data ?? const <DailyUsageMetrics>[];
          if (all.length < 14) {
            return _AnalyticsError(
              message: 'Focused could not build the full comparison window.',
              onRetry: _reload,
            );
          }

          final previous = all.take(7).toList(growable: false);
          final current = all.skip(7).take(7).toList(growable: false);
          final analytics = _AnalyticsSnapshot.build(
            current: current,
            previous: previous,
            usageProvider: usageProvider,
            focusProvider: focusProvider,
          );

          final currentStart = _dateOnly(current.first.day);
          final currentEndExclusive = DateTime(
            current.last.day.year,
            current.last.day.month,
            current.last.day.day + 1,
          );
          final previousStart = _dateOnly(previous.first.day);
          final previousEndExclusive = DateTime(
            previous.last.day.year,
            previous.last.day.month,
            previous.last.day.day + 1,
          );

          final currentExecution = _executionAnalyzer.summarizePeriod(
            startDay: currentStart,
            endDay: currentEndExclusive,
            occurrences: taskProvider.scheduledOccurrencesBetween(
              currentStart,
              currentEndExclusive,
            ),
            sessions: focusProvider.sessionHistory,
            analysesBySessionId: usageProvider.storedFocusAnalyses,
            activeTaskId: focusProvider.isRunning ? focusProvider.taskId : null,
            activeOccurrenceDate:
                focusProvider.isRunning ? focusProvider.taskOccurrenceDate : null,
            activeSessionStartedAt:
                focusProvider.isRunning ? focusProvider.sessionStartedAt : null,
            activeTaskScheduledStart:
                focusProvider.isRunning ? focusProvider.taskScheduledStart : null,
            activeTaskScheduledEnd:
                focusProvider.isRunning ? focusProvider.taskScheduledEnd : null,
            activeFocusIntervals: focusProvider.isRunning
                ? focusProvider.currentFocusIntervalsSnapshot
                : const [],
            asOf: _sameDate(current.last.day, today)
                ? DateTime.now()
                : null,
          );
          final previousExecution = _executionAnalyzer.summarizePeriod(
            startDay: previousStart,
            endDay: previousEndExclusive,
            occurrences: taskProvider.scheduledOccurrencesBetween(
              previousStart,
              previousEndExclusive,
            ),
            sessions: focusProvider.sessionHistory,
            analysesBySessionId: usageProvider.storedFocusAnalyses,
          );
          final currentHabits = habitProvider.analyticsForPeriod(
            startDay: currentStart,
            endDayExclusive: currentEndExclusive,
            asOf: _sameDate(current.last.day, today) ? DateTime.now() : null,
          );
          final previousHabits = habitProvider.analyticsForPeriod(
            startDay: previousStart,
            endDayExclusive: previousEndExclusive,
          );

          final atLatestRange = !_endDay.isBefore(today);

          return RefreshIndicator(
            onRefresh: () async {
              await usageProvider.refreshPermissionAndUsage(force: true);
              if (!mounted) {
                return;
              }
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                _PeriodHeader(
                  start: current.first.day,
                  end: current.last.day,
                  onEarlier: _earlier,
                  onNewer: atLatestRange ? null : _newer,
                ),
                const SizedBox(height: 18),
                _MetricGrid(analytics: analytics),
                const SizedBox(height: 26),
                _DailyTrendCard(days: current),
                const SizedBox(height: 26),
                _ScheduleExecutionCard(
                  current: currentExecution,
                  previous: previousExecution,
                ),
                const SizedBox(height: 26),
                _FocusQualityCard(analytics: analytics),
                const SizedBox(height: 26),
                _HabitConsistencyCard(
                  current: currentHabits,
                  previous: previousHabits,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsSnapshot {
  final List<DailyUsageMetrics> current;
  final List<DailyUsageMetrics> previous;
  final UsageDataCoverage currentCoverage;
  final UsageDataCoverage previousCoverage;
  final bool usageComparisonAllowed;

  final Duration currentUsage;
  final Duration previousUsage;
  final Duration currentProductive;
  final Duration previousProductive;
  final Duration currentDistracting;
  final Duration previousDistracting;

  final Duration currentFocus;
  final Duration previousFocus;
  final Duration? currentEffectiveFocus;
  final Duration? previousEffectiveFocus;
  final int? currentInterruptions;
  final int? previousInterruptions;
  final FocusAnalysisCoverage currentFocusCoverage;
  final FocusAnalysisCoverage previousFocusCoverage;
  final String? topInterrupter;

  const _AnalyticsSnapshot({
    required this.current,
    required this.previous,
    required this.currentCoverage,
    required this.previousCoverage,
    required this.usageComparisonAllowed,
    required this.currentUsage,
    required this.previousUsage,
    required this.currentProductive,
    required this.previousProductive,
    required this.currentDistracting,
    required this.previousDistracting,
    required this.currentFocus,
    required this.previousFocus,
    required this.currentEffectiveFocus,
    required this.previousEffectiveFocus,
    required this.currentInterruptions,
    required this.previousInterruptions,
    required this.currentFocusCoverage,
    required this.previousFocusCoverage,
    required this.topInterrupter,
  });

  factory _AnalyticsSnapshot.build({
    required List<DailyUsageMetrics> current,
    required List<DailyUsageMetrics> previous,
    required UsageProvider usageProvider,
    required FocusProvider focusProvider,
  }) {
    Duration sumMetric(
      List<DailyUsageMetrics> values,
      Duration Function(DailyUsageMetrics value) selector,
    ) {
      return values.fold(Duration.zero, (total, value) {
        return total + selector(value);
      });
    }

    Duration sumFocus(List<DailyUsageMetrics> values) {
      return values.fold(Duration.zero, (total, day) {
        return total + focusProvider.focusedDurationForDate(day.day);
      });
    }

    List<FocusSession> uniqueSessions(List<DailyUsageMetrics> values) {
      final byId = <String, FocusSession>{};
      for (final day in values) {
        for (final session in focusProvider.sessionsForDate(day.day)) {
          byId[session.id] = session;
        }
      }
      return byId.values.toList(growable: false);
    }

    Duration knownDistraction(List<DailyUsageMetrics> values) {
      return values.fold(Duration.zero, (total, day) {
        return total + usageProvider.focusDistractedDurationForDate(day.day);
      });
    }

    int interruptionCount(List<DailyUsageMetrics> values) {
      return values.fold(0, (total, day) {
        return total + usageProvider.focusInterruptionCountForDate(day.day);
      });
    }

    final currentCoverage = usageProvider.coverageForDailyUsage(current);
    final previousCoverage = usageProvider.coverageForDailyUsage(previous);
    final currentSessions = uniqueSessions(current);
    final previousSessions = uniqueSessions(previous);
    final currentFocusCoverage =
        usageProvider.focusAnalysisCoverageForSessions(currentSessions);
    final previousFocusCoverage =
        usageProvider.focusAnalysisCoverageForSessions(previousSessions);
    final currentFocus = sumFocus(current);
    final previousFocus = sumFocus(previous);
    final currentDistractedFocus = knownDistraction(current);
    final previousDistractedFocus = knownDistraction(previous);

    Duration effective(Duration focus, Duration distraction) {
      final seconds = math.max(0, focus.inSeconds - distraction.inSeconds).toInt();
      return Duration(seconds: seconds);
    }

    final currentStart = current.first.day;
    final currentEnd = DateTime(
      current.last.day.year,
      current.last.day.month,
      current.last.day.day + 1,
    );

    return _AnalyticsSnapshot(
      current: current,
      previous: previous,
      currentCoverage: currentCoverage,
      previousCoverage: previousCoverage,
      usageComparisonAllowed:
          usageProvider.canCompareUsagePeriods(current, previous),
      currentUsage: sumMetric(current, (day) => day.totalUsage),
      previousUsage: sumMetric(previous, (day) => day.totalUsage),
      currentProductive: sumMetric(current, (day) => day.productiveUsage),
      previousProductive: sumMetric(previous, (day) => day.productiveUsage),
      currentDistracting: sumMetric(current, (day) => day.distractingUsage),
      previousDistracting:
          sumMetric(previous, (day) => day.distractingUsage),
      currentFocus: currentFocus,
      previousFocus: previousFocus,
      currentEffectiveFocus: currentFocusCoverage.isComplete
          ? effective(currentFocus, currentDistractedFocus)
          : null,
      previousEffectiveFocus: previousFocusCoverage.isComplete
          ? effective(previousFocus, previousDistractedFocus)
          : null,
      currentInterruptions:
          currentFocusCoverage.isComplete ? interruptionCount(current) : null,
      previousInterruptions:
          previousFocusCoverage.isComplete ? interruptionCount(previous) : null,
      currentFocusCoverage: currentFocusCoverage,
      previousFocusCoverage: previousFocusCoverage,
      topInterrupter:
          usageProvider.topInterrupterForRange(currentStart, currentEnd),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final VoidCallback onEarlier;
  final VoidCallback? onNewer;

  const _PeriodHeader({
    required this.start,
    required this.end,
    required this.onEarlier,
    required this.onNewer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(end)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Earlier 7 days',
          onPressed: onEarlier,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Newer 7 days',
          onPressed: onNewer,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final UsageDataCoverage current;
  final UsageDataCoverage previous;
  final bool comparisonAllowed;

  const _CoverageCard({
    required this.current,
    required this.previous,
    required this.comparisonAllowed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data quality',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${current.measuredDays}/${current.totalDays} measured • ${current.completeDays} complete',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: current.ratio,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SourceChip(
                icon: Icons.phone_android_rounded,
                label: 'Live ${current.liveAndroidDays}',
              ),
              _SourceChip(
                icon: Icons.history_rounded,
                label: 'Android history ${current.androidHistoryDays}',
              ),
              _SourceChip(
                icon: Icons.storage_rounded,
                label: 'Stored ${current.focusedStorageDays}',
              ),
              if (current.partialDays > 0)
                _SourceChip(
                  icon: Icons.timelapse_rounded,
                  label: 'Partial ${current.partialDays}',
                ),
              if (current.missingDays > 0)
                _SourceChip(
                  icon: Icons.remove_circle_outline_rounded,
                  label: 'Missing ${current.missingDays}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comparisonAllowed
                ? 'Previous-period comparisons are enabled: both 7-day windows have at least 5 measured days. When coverage is incomplete, comparison percentages use the measured-day average instead of pretending missing days were zero.'
                : 'Comparison withheld. Focused requires at least 5 measured days in both 7-day windows before showing a percentage change.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          if (!comparisonAllowed) ...[
            const SizedBox(height: 5),
            Text(
              'Previous window: ${previous.measuredDays}/${previous.totalDays} measured.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SourceChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final _AnalyticsSnapshot analytics;

  const _MetricGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<UsageProvider>();
    final allowed = analytics.usageComparisonAllowed;

    Duration completeDayAverage(
      List<DailyUsageMetrics> days,
      Duration Function(DailyUsageMetrics day) selector,
    ) {
      final complete = days.where((day) => day.measured && day.completeDay);
      var count = 0;
      var milliseconds = 0;
      for (final day in complete) {
        count++;
        milliseconds += selector(day).inMilliseconds;
      }
      if (count == 0) {
        return Duration.zero;
      }
      return Duration(milliseconds: milliseconds ~/ count);
    }

    double? usageChange(
      Duration Function(DailyUsageMetrics day) selector,
    ) {
      return provider.compareDurationsPercent(
        completeDayAverage(analytics.current, selector),
        completeDayAverage(analytics.previous, selector),
        comparisonAllowed: allowed,
      );
    }

    String usageValue(
      Duration total,
      Duration Function(DailyUsageMetrics day) selector,
    ) {
      if (analytics.currentCoverage.completeDays == 0) {
        return '—';
      }
      if (analytics.currentCoverage.isComplete) {
        return _formatDuration(total);
      }
      return '${_formatDuration(completeDayAverage(analytics.current, selector))}/day';
    }

    final items = [
      _MetricValue(
        label: analytics.currentCoverage.isComplete
            ? 'Screen time'
            : 'Screen time avg',
        value: usageValue(
          analytics.currentUsage,
          (day) => day.totalUsage,
        ),
        change: usageChange((day) => day.totalUsage),
        icon: Icons.phone_android_rounded,
      ),
      _MetricValue(
        label: analytics.currentCoverage.isComplete
            ? 'Distracting'
            : 'Distracting avg',
        value: usageValue(
          analytics.currentDistracting,
          (day) => day.distractingUsage,
        ),
        change: usageChange((day) => day.distractingUsage),
        icon: Icons.notifications_active_outlined,
      ),
      _MetricValue(
        label: analytics.currentCoverage.isComplete
            ? 'Productive apps'
            : 'Productive avg',
        value: usageValue(
          analytics.currentProductive,
          (day) => day.productiveUsage,
        ),
        change: usageChange((day) => day.productiveUsage),
        icon: Icons.auto_awesome_rounded,
      ),
      _MetricValue(
        label: 'Focused',
        value: _formatDuration(analytics.currentFocus),
        change: _focusChange(
          analytics.currentFocus,
          analytics.previousFocus,
        ),
        icon: Icons.center_focus_strong_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 680 ? 4 : 2;
        final gap = 10.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _MetricCard(value: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricValue {
  final String label;
  final String value;
  final double? change;
  final IconData icon;
  const _MetricValue({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricValue value;

  const _MetricCard({required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final change = value.change;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(value.icon, color: scheme.primary),
          const SizedBox(height: 14),
          Text(
            value.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            value.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            change == null ? 'Comparison unavailable' : _changeLabel(change),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  final List<DailyUsageMetrics> days;

  const _DailyTrendCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final measuredDays = days.where((day) => day.measured).toList();
    if (measuredDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          'Daily screen-time history will appear here as Focused measures it on this device.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final maxSeconds = measuredDays.fold<int>(1, (value, day) {
      return math.max(value, day.totalUsage.inSeconds);
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily screen time',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'A simple view of your screen time across the week.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: measuredDays.map((day) {
                final ratio = day.totalUsage.inSeconds / maxSeconds;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio.clamp(0.03, 1.0),
                              child: Container(
                                width: 22,
                                decoration: BoxDecoration(
                                  color: day.completeDay
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('E').format(day.day).substring(0, 1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 3),
                        Icon(
                          _provenanceIcon(day.provenance),
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusQualityCard extends StatelessWidget {
  final _AnalyticsSnapshot analytics;

  const _FocusQualityCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = analytics.currentFocusCoverage.isComplete;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.center_focus_strong_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Focus summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SmallFocusMetric(
                label: 'Focused',
                value: _formatDuration(analytics.currentFocus),
              ),
              _SmallFocusMetric(
                label: 'Effective focus',
                value: analytics.currentEffectiveFocus == null
                    ? '—'
                    : _formatDuration(analytics.currentEffectiveFocus!),
              ),
              _SmallFocusMetric(
                label: 'Interruptions',
                value: analytics.currentInterruptions?.toString() ?? '—',
              ),
              _SmallFocusMetric(
                label: 'Top interrupter',
                value: analytics.topInterrupter ?? 'None',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (analytics.currentEffectiveFocus != null &&
              analytics.previousEffectiveFocus != null) ...[
            Text(
              'Effective focus ${_changeLabel(_focusChange(analytics.currentEffectiveFocus!, analytics.previousEffectiveFocus!) ?? 0.0)}. '
              'Interruptions ${_countComparisonLabel(analytics.currentInterruptions, analytics.previousInterruptions)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            complete
                ? 'Focus and interruption totals are available for this 7-day period.'
                : 'Some focus sessions do not have interruption analysis yet, so effective-focus totals may be incomplete.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _SmallFocusMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SmallFocusMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}


class _ScheduleExecutionCard extends StatelessWidget {
  final TaskExecutionPeriodSummary current;
  final TaskExecutionPeriodSummary previous;

  const _ScheduleExecutionCard({
    required this.current,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delay = current.averageStartDelay;
    final previousDelay = previous.averageStartDelay;
    final effective = current.effectiveFocusDuration;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule execution',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calendar plans compared with real focus starts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ExecutionRateRow(
            label: 'Scheduled tasks',
            value: '${current.scheduledCount}',
            supporting: '${current.startedCount}/${current.startEligibleCount} started • ${current.completedCount}/${current.completionEligibleCount} completed',
          ),
          const SizedBox(height: 12),
          _ExecutionRateRow(
            label: 'Started on time',
            value: current.startedCount == 0
                ? '—'
                : '${current.onTimeRatePercent.round()}%',
            supporting: _percentagePointChange(
              current.onTimeRatePercent,
              previous.onTimeRatePercent,
              available: current.startedCount > 0 && previous.startedCount > 0,
            ),
          ),
          const SizedBox(height: 12),
          _ExecutionRateRow(
            label: 'Completed',
            value: current.completionEligibleCount == 0
                ? '—'
                : '${current.completionRatePercent.round()}%',
            supporting: _percentagePointChange(
              current.completionRatePercent,
              previous.completionRatePercent,
              available: current.completionEligibleCount > 0 &&
                  previous.completionEligibleCount > 0,
            ),
          ),
          const SizedBox(height: 12),
          _ExecutionRateRow(
            label: 'Average start delay',
            value: delay == null ? '—' : _formatDurationShort(delay),
            supporting: _delayComparison(delay, previousDelay),
          ),
          const SizedBox(height: 18),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Planned',
                  value: _formatDurationShort(current.plannedDuration),
                ),
              ),
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Active focus',
                  value: _formatDurationShort(current.activeFocusDuration),
                ),
              ),
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Effective',
                  value: effective == null
                      ? '—'
                      : _formatDurationShort(effective),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            current.scheduledCount == 0
                ? 'No scheduled task occurrences in this window.'
                : 'Plan coverage ${current.planCoveragePercent.round()}%${current.effectiveCoveragePercent == null ? '' : ' • effective coverage ${current.effectiveCoveragePercent!.round()}%'}.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          if (!current.effectiveFocusAvailable && current.startedCount > 0) ...[
            const SizedBox(height: 7),
            Text(
              'Effective-focus totals are withheld until every linked completed focus session has a saved interruption analysis.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExecutionRateRow extends StatelessWidget {
  final String label;
  final String value;
  final String supporting;

  const _ExecutionRateRow({
    required this.label,
    required this.value,
    required this.supporting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                supporting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ExecutionTimeColumn extends StatelessWidget {
  final String label;
  final String value;

  const _ExecutionTimeColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

String _percentagePointChange(
  double current,
  double previous, {
  required bool available,
}) {
  if (!available) return 'Previous comparison unavailable';
  final change = current - previous;
  if (change.abs() < 0.5) return 'Stable vs previous 7 days';
  final direction = change > 0 ? 'up' : 'down';
  return '${change.abs().round()} percentage points $direction';
}

String _delayComparison(Duration? current, Duration? previous) {
  if (current == null || previous == null) {
    return 'Previous comparison unavailable';
  }
  final delta = current - previous;
  if (delta.inSeconds.abs() < 30) return 'Stable vs previous 7 days';
  return delta.isNegative
      ? '${_formatDurationShort(delta)} better than previous'
      : '${_formatDurationShort(delta)} slower than previous';
}

String _formatDurationShort(Duration value) {
  final minutes = value.inMinutes.abs();
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _HabitConsistencyCard extends StatelessWidget {
  final HabitPeriodSummary current;
  final HabitPeriodSummary previous;

  const _HabitConsistencyCard({
    required this.current,
    required this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCurrent = current.scheduledOccurrences > 0;
    final hasPrevious = previous.scheduledOccurrences > 0;
    final currentPercent = current.completionRate * 100;
    final previousPercent = previous.completionRate * 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habit consistency',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed scheduled habit occurrences',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Consistency',
                  value: hasCurrent ? '${currentPercent.round()}%' : '—',
                ),
              ),
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Completed',
                  value: '${current.completedOccurrences}/${current.scheduledOccurrences}',
                ),
              ),
              Expanded(
                child: _ExecutionTimeColumn(
                  label: 'Active habits',
                  value: '${current.activeHabitCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasCurrent
                ? _percentagePointChange(
                    currentPercent,
                    previousPercent,
                    available: hasPrevious,
                  )
                : 'No completed-day habit occurrences in this window yet.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            'The still-open current day is excluded from this weekly trend so unfinished habits today are not counted as historical failures.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _DailyDataList extends StatelessWidget {
  final List<DailyUsageMetrics> days;
  final FocusProvider focusProvider;

  const _DailyDataList({
    required this.days,
    required this.focusProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily measurements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: List.generate(days.length, (index) {
              final day = days[index];
              final focus = focusProvider.focusedDurationForDate(day.day);
              return Column(
                children: [
                  ListTile(
                    leading: Icon(_provenanceIcon(day.provenance)),
                    title: Text(
                      DateFormat('EEEE, MMM d').format(day.day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${day.provenance.label}${day.completeDay ? '' : ' • Partial day'} • Focus ${_formatDuration(focus)}',
                    ),
                    trailing: Text(
                      day.measured ? _formatDuration(day.totalUsage) : '—',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (index != days.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context).dividerColor,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AnalyticsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Could not build analytics',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

IconData _provenanceIcon(UsageDataProvenance provenance) {
  switch (provenance) {
    case UsageDataProvenance.liveAndroid:
      return Icons.phone_android_rounded;
    case UsageDataProvenance.focusedStorage:
      return Icons.storage_rounded;
    case UsageDataProvenance.androidHistory:
      return Icons.history_rounded;
    case UsageDataProvenance.missing:
      return Icons.remove_circle_outline_rounded;
  }
}

String _formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes <= 0) {
    return duration.inSeconds > 0 ? '${duration.inSeconds}s' : '0m';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) {
    return '${minutes}m';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

String _changeLabel(double value) {
  final rounded = value.abs().round();
  if (rounded == 0) {
    return 'About the same';
  }
  return '${value < 0 ? '↓' : '↑'} $rounded% vs previous 7d';
}

double? _focusChange(Duration current, Duration previous) {
  if (previous.inSeconds == 0) {
    return current.inSeconds == 0 ? 0 : null;
  }
  return ((current.inSeconds - previous.inSeconds) / previous.inSeconds) * 100;
}

String _countComparisonLabel(int? current, int? previous) {
  if (current == null || previous == null) {
    return 'comparison unavailable';
  }
  if (previous == 0) {
    return current == 0 ? 'about the same' : 'no previous baseline';
  }
  final change = ((current - previous) / previous) * 100;
  final rounded = change.abs().round();
  if (rounded == 0) {
    return 'about the same';
  }
  return '${change < 0 ? '↓' : '↑'} $rounded% vs previous 7d';
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

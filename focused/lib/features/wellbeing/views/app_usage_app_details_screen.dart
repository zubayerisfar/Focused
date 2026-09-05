import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/app_category.dart';
import '../../../models/app_open_event.dart';
import '../../../models/notification_event.dart';
import '../../../models/app_usage_history_point.dart';
import '../../../providers/usage_provider.dart';
import '../../../services/notification_access_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

class AppUsageAppDetailsScreen extends StatefulWidget {
  final String appId;
  final String? initialAppName;

  const AppUsageAppDetailsScreen({
    super.key,
    required this.appId,
    this.initialAppName,
  });

  @override
  State<AppUsageAppDetailsScreen> createState() =>
      _AppUsageAppDetailsScreenState();
}

class _AppDailyOpensHistory {
  final List<int> dailyCounts;
  final List<DateTime> days;
  final double averageOpens;
  final int totalOpens;
  final double? trend;

  const _AppDailyOpensHistory({
    required this.dailyCounts,
    required this.days,
    required this.averageOpens,
    required this.totalOpens,
    required this.trend,
  });
}

class _AppUsageAppDetailsScreenState extends State<AppUsageAppDetailsScreen> {
  int _days = 7;
  late DateTime _endDay;
  late Future<List<AppUsageHistoryPoint>> _historyFuture;
  late Future<_AppDailyOpensHistory> _opensHistoryFuture;
  late Future<_AppBehaviorData> _behaviorFuture;
  final NotificationAccessService _notificationAccessService =
      NotificationAccessService();

  @override
  void initState() {
    super.initState();
    _endDay = _startOfDay(DateTime.now());
    _historyFuture = _load();
    _opensHistoryFuture = _loadOpensHistory();
    _behaviorFuture = _loadBehavior();
    unawaited(context.read<UsageProvider>().ensureAppMetadata(widget.appId));
  }

  Future<List<AppUsageHistoryPoint>> _load() {
    return context.read<UsageProvider>().loadAppUsageHistory(
      widget.appId,
      days: _days,
      endDay: _endDay,
    );
  }

  Future<_AppDailyOpensHistory> _loadOpensHistory() async {
    final provider = context.read<UsageProvider>();
    final startDay = DateTime(
      _endDay.year,
      _endDay.month,
      _endDay.day - (_days - 1),
    );
    final nextDayOfEnd = _endDay.add(const Duration(days: 1));

    // Previous window for trend
    final prevEnd = DateTime(_endDay.year, _endDay.month, _endDay.day - _days);
    final prevStart = DateTime(
      prevEnd.year,
      prevEnd.month,
      prevEnd.day - (_days - 1),
    );
    final nextDayOfPrevEnd = prevEnd.add(const Duration(days: 1));

    final results = await Future.wait([
      provider.loadAppOpenEvents(
        start: startDay,
        end: nextDayOfEnd,
        appId: widget.appId,
      ),
      provider.loadAppOpenEvents(
        start: prevStart,
        end: nextDayOfPrevEnd,
        appId: widget.appId,
      ),
    ]);

    final currentEvents = results[0];
    final prevEvents = results[1];

    final daysList = <DateTime>[];
    for (int i = 0; i < _days; i++) {
      daysList.add(DateTime(startDay.year, startDay.month, startDay.day + i));
    }

    final countsMap = <String, int>{};
    for (final e in currentEvents) {
      final key = '${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}';
      countsMap[key] = (countsMap[key] ?? 0) + 1;
    }

    final dailyCounts = daysList.map((d) {
      final key = '${d.year}-${d.month}-${d.day}';
      return countsMap[key] ?? 0;
    }).toList();

    final totalOpens = dailyCounts.fold<int>(0, (sum, c) => sum + c);
    final avgOpens = dailyCounts.isEmpty
        ? 0.0
        : totalOpens / dailyCounts.length;

    double? trend;
    final prevTotal = prevEvents.length;
    if (prevTotal > 0) {
      trend = ((totalOpens - prevTotal) / prevTotal) * 100.0;
    } else if (totalOpens > 0) {
      trend = 100.0;
    }

    return _AppDailyOpensHistory(
      dailyCounts: dailyCounts,
      days: daysList,
      averageOpens: avgOpens,
      totalOpens: totalOpens,
      trend: trend,
    );
  }

  void _reload() {
    unawaited(
      context.read<UsageProvider>().ensureAppMetadata(
        widget.appId,
        force: true,
      ),
    );
    setState(() {
      _historyFuture = _load();
      _opensHistoryFuture = _loadOpensHistory();
      _behaviorFuture = _loadBehavior();
    });
  }

  Future<_AppBehaviorData> _loadBehavior() async {
    final provider = context.read<UsageProvider>();
    final now = DateTime.now();
    final today = _startOfDay(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final notificationAccess = await _notificationAccessService.hasAccess();
    final results = await Future.wait<dynamic>([
      provider.loadAppOpenEvents(start: today, end: now, appId: widget.appId),
      provider.loadAppOpenEvents(
        start: yesterday,
        end: today,
        appId: widget.appId,
      ),
      if (notificationAccess)
        provider.loadNotificationEvents(
          start: today,
          end: now,
          appId: widget.appId,
        )
      else
        Future.value(const []),
      if (notificationAccess)
        provider.loadNotificationEvents(
          start: yesterday,
          end: today,
          appId: widget.appId,
        )
      else
        Future.value(const []),
    ]);

    final todayOpens = List<AppOpenEvent>.from(results[0] as List);
    final yesterdayOpens = List<AppOpenEvent>.from(results[1] as List);
    final todayNotifications = List<NotificationEvent>.from(results[2] as List);
    final yesterdayNotifications = List<NotificationEvent>.from(
      results[3] as List,
    );

    final openHours = List<int>.filled(24, 0);
    for (final event in todayOpens) {
      final timestamp = event.timestamp;
      openHours[timestamp.hour] += 1;
    }

    final notificationHours = List<int>.filled(24, 0);
    for (final event in todayNotifications) {
      final timestamp = event.timestamp;
      notificationHours[timestamp.hour] += 1;
    }

    return _AppBehaviorData(
      hourlyUsage: provider.hourlyUsageForAppToday(widget.appId),
      usageToday: provider.appUsageToday(widget.appId),
      usageYesterday: provider.appUsageYesterday(widget.appId),
      usageChangePercent: provider.getAppChangePercentById(widget.appId),
      opensToday: todayOpens.length,
      opensYesterday: yesterdayOpens.length,
      hourlyOpens: openHours,
      notificationsToday: todayNotifications.length,
      notificationsYesterday: yesterdayNotifications.length,
      hourlyNotifications: notificationHours,
      notificationAccessGranted: notificationAccess,
      focusDistraction: provider.focusDistractionDurationForApp(
        widget.appId,
        start: today,
        end: now,
      ),
      focusInterruptions: provider.focusInterruptionCountForApp(
        widget.appId,
        start: today,
        end: now,
      ),
    );
  }

  void _changeDays(int days) {
    if (_days == days) return;
    setState(() {
      _days = days;
      _historyFuture = _load();
      _opensHistoryFuture = _loadOpensHistory();
    });
  }

  void _goEarlier() {
    setState(() {
      _endDay = DateTime(_endDay.year, _endDay.month, _endDay.day - _days);
      _historyFuture = _load();
      _opensHistoryFuture = _loadOpensHistory();
    });
  }

  void _goNewer() {
    final today = _startOfDay(DateTime.now());
    final candidate = DateTime(
      _endDay.year,
      _endDay.month,
      _endDay.day + _days,
    );
    setState(() {
      _endDay = candidate.isAfter(today) ? today : candidate;
      _historyFuture = _load();
      _opensHistoryFuture = _loadOpensHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsageProvider>();
    final metadata = provider.getAppMetadata(widget.appId);
    final appName = provider.resolveDisplayName(
      widget.appId,
      fallback: provider.resolveAppName(
        widget.appId,
        fallback: widget.initialAppName,
      ),
    );
    final category = provider.getAppCategory(widget.appId);

    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<AppUsageHistoryPoint>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          final points = snapshot.data ?? const <AppUsageHistoryPoint>[];
          final latest = points.isEmpty ? null : points.last;
          final trend = points.isEmpty
              ? null
              : provider.usageTrendPercent(points);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            children: [
              _AppHeader(
                appName: appName,
                iconBytes: metadata?.iconBytes,
                category: category,
                latestUsage: latest?.measured == true ? latest!.usage : null,
                change: provider.getAppChangePercentById(widget.appId),
              ),
              const SizedBox(height: 20),
              _CategoryCard(
                selected: category,
                onChanged: (value) =>
                    provider.setAppCategory(widget.appId, value),
              ),
              const SizedBox(height: 26),
              _HistoryHeader(
                days: _days,
                endDay: _endDay,
                availableStartDay: points.isEmpty
                    ? provider.usageHistoryStartDay
                    : points.first.day,
                onDaysChanged: _changeDays,
                onEarlier: _canGoEarlier(provider) ? _goEarlier : null,
                onNewer: _isCurrentWindow ? null : _goNewer,
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _MessageCard(
                  text: 'Could not load this app’s usage history.',
                  action: 'Try again',
                  onTap: _reload,
                )
              else
                _UsageHistoryCard(points: points, trend: trend),
              const SizedBox(height: 16),
              FutureBuilder<_AppDailyOpensHistory>(
                future: _opensHistoryFuture,
                builder: (context, opensSnapshot) {
                  if (opensSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (opensSnapshot.hasError || opensSnapshot.data == null) {
                    return const SizedBox.shrink();
                  }
                  return _OpensHistoryCard(data: opensSnapshot.data!);
                },
              ),
              const SizedBox(height: 26),
              FutureBuilder<_AppBehaviorData>(
                future: _behaviorFuture,
                builder: (context, behaviorSnapshot) {
                  if (behaviorSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(
                      height: 140,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (behaviorSnapshot.hasError ||
                      behaviorSnapshot.data == null) {
                    return _MessageCard(
                      text: 'Could not load today’s behavioural metrics.',
                      action: 'Try again',
                      onTap: _reload,
                    );
                  }
                  return _BehaviorSection(data: behaviorSnapshot.data!);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  bool get _isCurrentWindow => !_endDay.isBefore(_startOfDay(DateTime.now()));

  bool _canGoEarlier(UsageProvider provider) {
    final start = provider.usageHistoryStartDay;
    if (start == null) return true;
    final currentStart = DateTime(
      _endDay.year,
      _endDay.month,
      _endDay.day - (_days - 1),
    );
    return currentStart.isAfter(start);
  }
}

class _AppBehaviorData {
  const _AppBehaviorData({
    required this.hourlyUsage,
    required this.usageToday,
    required this.usageYesterday,
    required this.usageChangePercent,
    required this.opensToday,
    required this.opensYesterday,
    required this.hourlyOpens,
    required this.notificationsToday,
    required this.notificationsYesterday,
    required this.hourlyNotifications,
    required this.notificationAccessGranted,
    required this.focusDistraction,
    required this.focusInterruptions,
  });

  final List<Duration> hourlyUsage;
  final Duration usageToday;
  final Duration usageYesterday;
  final double? usageChangePercent;
  final int opensToday;
  final int opensYesterday;
  final List<int> hourlyOpens;
  final int notificationsToday;
  final int notificationsYesterday;
  final List<int> hourlyNotifications;
  final bool notificationAccessGranted;
  final Duration focusDistraction;
  final int focusInterruptions;
}

class _BehaviorSection extends StatelessWidget {
  const _BehaviorSection({required this.data});

  final _AppBehaviorData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today’s behaviour',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _YesterdayVsTodayCard(data: data),
        const SizedBox(height: 12),
        _HourlyMetricCard(
          title: 'Today’s hourly usage',
          subtitle: 'When this app used your screen time today',
          values: data.hourlyUsage
              .map((duration) => duration.inSeconds.toDouble())
              .toList(growable: false),
          totalLabel: _duration(
            data.hourlyUsage.fold(
              Duration.zero,
              (total, value) => total + value,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MetricCountCard(
          title: 'Times opened',
          value: data.opensToday,
          comparison: _countComparison(data.opensToday, data.opensYesterday),
          hourlyValues: data.hourlyOpens,
        ),
        const SizedBox(height: 12),
        if (data.notificationAccessGranted)
          _MetricCountCard(
            title: 'Notifications received',
            value: data.notificationsToday,
            comparison: _countComparison(
              data.notificationsToday,
              data.notificationsYesterday,
            ),
            hourlyValues: data.hourlyNotifications,
          )
        else
          _MessageCard(
            text:
                'Enable Notification Access in Settings to count notifications from this app. Focused does not store notification content.',
          ),
        const SizedBox(height: 12),
        _FocusImpactCard(
          distraction: data.focusDistraction,
          interruptions: data.focusInterruptions,
        ),
      ],
    );
  }
}

class _YesterdayVsTodayCard extends StatelessWidget {
  const _YesterdayVsTodayCard({required this.data});

  final _AppBehaviorData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = data.usageChangePercent;

    return _MetricSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yesterday vs. Today',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct comparison of screen time and launches',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (change > 0
                                ? AppTheme.danger
                                : change < 0
                                ? AppTheme.success
                                : theme.colorScheme.onSurfaceVariant)
                            .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change > 0
                            ? Icons.arrow_upward_rounded
                            : change < 0
                            ? Icons.arrow_downward_rounded
                            : Icons.remove_rounded,
                        size: 13,
                        color: change > 0
                            ? AppTheme.danger
                            : change < 0
                            ? AppTheme.success
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${change.abs().round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: change > 0
                              ? AppTheme.danger
                              : change < 0
                              ? AppTheme.success
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yesterday',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _duration(data.usageYesterday),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.opensYesterday} opens',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _duration(data.usageToday),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.opensToday} opens',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _HourlyMetricCard extends StatelessWidget {
  const _HourlyMetricCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.totalLabel,
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return _MetricSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                totalLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HourlyBars(values: values),
        ],
      ),
    );
  }
}

class _MetricCountCard extends StatelessWidget {
  const _MetricCountCard({
    required this.title,
    required this.value,
    required this.comparison,
    required this.hourlyValues,
  });

  final String title;
  final int value;
  final String comparison;
  final List<int> hourlyValues;

  @override
  Widget build(BuildContext context) {
    return _MetricSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comparison,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          _HourlyBars(
            values: hourlyValues
                .map((value) => value.toDouble())
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _FocusImpactCard extends StatelessWidget {
  const _FocusImpactCard({
    required this.distraction,
    required this.interruptions,
  });

  final Duration distraction;
  final int interruptions;

  @override
  Widget build(BuildContext context) {
    return _MetricSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus impact',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Distracting time',
                  value: _duration(distraction),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'Interruptions',
                  value: '$interruptions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetricSurface extends StatelessWidget {
  const _MetricSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _HourlyBars extends StatelessWidget {
  const _HourlyBars({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final normalized = List<double>.generate(
      24,
      (index) => index < values.length ? values[index] : 0,
      growable: false,
    );
    final maxValue = normalized.fold<double>(0, math.max);
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (index) {
              final fraction = maxValue <= 0
                  ? 0.0
                  : normalized[index] / maxValue;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: math.max(2.0, 92 * fraction),
                      decoration: BoxDecoration(
                        color: fraction == 0
                            ? Theme.of(context).dividerColor.withOpacity(0.35)
                            : color.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('12a', style: TextStyle(fontSize: 10)),
            Text('6a', style: TextStyle(fontSize: 10)),
            Text('12p', style: TextStyle(fontSize: 10)),
            Text('6p', style: TextStyle(fontSize: 10)),
            Text('11p', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

String _countComparison(int today, int yesterday) {
  if (yesterday == 0) {
    return today == 0 ? 'Same as yesterday' : 'New today';
  }
  final percent = ((today - yesterday) / yesterday) * 100;
  if (percent == 0) return 'Same as yesterday';
  return '${percent > 0 ? '↑' : '↓'} ${percent.abs().round()}% vs yesterday';
}

class _AppHeader extends StatelessWidget {
  final String appName;
  final dynamic iconBytes;
  final AppCategory category;
  final Duration? latestUsage;
  final double? change;

  const _AppHeader({
    required this.appName,
    required this.iconBytes,
    required this.category,
    required this.latestUsage,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          AppIcon(
            iconBytes: iconBytes,
            appName: appName,
            size: 58,
            borderRadius: 18,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                _CategoryPill(category: category),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latestUsage == null ? '—' : _duration(latestUsage!),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              _TrendText(value: change),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AppCategory selected;
  final ValueChanged<AppCategory> onChanged;

  const _CategoryCard({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark app category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose how this app fits your day. Focused uses this when '
            'showing productive and distracting time.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppCategory.values.map((value) {
              final selectedNow = value == selected;
              final color = _categoryColor(value);
              return ChoiceChip(
                showCheckmark: false,
                selected: selectedNow,
                onSelected: (_) => onChanged(value),
                avatar: Icon(
                  _categoryIcon(value),
                  size: 17,
                  color: selectedNow
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  _categoryLabel(value),
                  style: TextStyle(
                    color: selectedNow
                        ? color
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
                selectedColor: color.withOpacity(0.14),
                side: BorderSide(
                  color: selectedNow
                      ? color.withOpacity(0.45)
                      : Theme.of(context).dividerColor,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int days;
  final DateTime endDay;
  final DateTime? availableStartDay;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback? onEarlier;
  final VoidCallback? onNewer;

  const _HistoryHeader({
    required this.days,
    required this.endDay,
    required this.availableStartDay,
    required this.onDaysChanged,
    required this.onEarlier,
    required this.onNewer,
  });

  @override
  Widget build(BuildContext context) {
    final requestedStart = DateTime(
      endDay.year,
      endDay.month,
      endDay.day - (days - 1),
    );
    final start =
        availableStartDay != null && availableStartDay!.isAfter(requestedStart)
        ? availableStartDay!
        : requestedStart;
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
                    'Usage history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('MMM d').format(start)} – '
                    '${DateFormat('MMM d').format(endDay)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Earlier',
              onPressed: onEarlier,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Newer',
              onPressed: onNewer,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [7, 14, 30, 90].map((value) {
            final selectedNow = days == value;
            final scheme = Theme.of(context).colorScheme;
            return ChoiceChip(
              showCheckmark: false,
              selected: selectedNow,
              backgroundColor: scheme.surfaceContainerHigh,
              selectedColor: scheme.primaryContainer,
              label: Text(
                '${value}d',
                style: TextStyle(
                  color: selectedNow
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onSelected: (_) => onDaysChanged(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _UsageHistoryCard extends StatelessWidget {
  final List<AppUsageHistoryPoint> points;
  final double? trend;

  const _UsageHistoryCard({required this.points, required this.trend});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || !points.any((point) => point.measured)) {
      return const _MessageCard(
        text: 'There is not enough measured history for this app yet.',
      );
    }

    final measured = points.where((point) => point.measured).toList();
    final averageSeconds =
        measured.fold<int>(0, (sum, point) => sum + point.usage.inSeconds) ~/
        measured.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Average',
                      style: TextStyle(fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _duration(Duration(seconds: averageSeconds)),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _TrendBadge(value: trend),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: _HistoryPainter(
                points: points,
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.09),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d').format(points.first.day),
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                DateFormat('MMM d').format(points[points.length ~/ 2].day),
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                DateFormat('MMM d').format(points.last.day),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  final List<AppUsageHistoryPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color fillColor;

  const _HistoryPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withOpacity(0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final maxSeconds = math.max(
      1,
      points
          .where((point) => point.measured)
          .map((point) => point.usage.inSeconds)
          .fold<int>(0, math.max),
    );

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = lineColor;

    Path? currentPath;
    final segmentPoints = <Offset>[];

    void finishSegment() {
      if (currentPath == null || segmentPoints.isEmpty) return;
      if (segmentPoints.length > 1) {
        final fill = Path.from(currentPath!)
          ..lineTo(segmentPoints.last.dx, size.height)
          ..lineTo(segmentPoints.first.dx, size.height)
          ..close();
        canvas.drawPath(fill, Paint()..color = fillColor);
      }
      canvas.drawPath(currentPath!, linePaint);
      for (final point in segmentPoints) {
        canvas.drawCircle(point, 2.6, dotPaint);
      }
      currentPath = null;
      segmentPoints.clear();
    }

    // Draw Y-axis usage duration labels
    final textStyle = TextStyle(
      color: gridColor.withOpacity(0.9),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    void drawTimeLabel(String text, double y) {
      final span = TextSpan(text: text, style: textStyle);
      final tp = TextPainter(text: span, textDirection: ui.TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(4, (y - 12).clamp(0, size.height - 14)));
    }

    drawTimeLabel(_duration(Duration(seconds: maxSeconds)), 0);
    drawTimeLabel(
      _duration(Duration(seconds: maxSeconds ~/ 2)),
      size.height / 2,
    );
    drawTimeLabel('0m', size.height);

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (!point.measured) {
        finishSegment();
        continue;
      }

      final x = points.length == 1
          ? 0.0
          : size.width * index / (points.length - 1);
      final y =
          size.height -
          (point.usage.inSeconds / maxSeconds) * size.height * 0.82;
      final offset = Offset(x, y);

      currentPath ??= Path()..moveTo(offset.dx, offset.dy);
      if (segmentPoints.isNotEmpty) {
        final previous = segmentPoints.last;
        final midX = (previous.dx + offset.dx) / 2;
        currentPath!.cubicTo(
          midX,
          previous.dy,
          midX,
          offset.dy,
          offset.dx,
          offset.dy,
        );
      }
      segmentPoints.add(offset);
    }
    finishSegment();

    // Draw usage time labels above points for short intervals (e.g. 7d or 14d)
    if (points.length <= 14) {
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        if (!point.measured || point.usage.inMinutes == 0) continue;

        final x = points.length == 1
            ? 0.0
            : size.width * index / (points.length - 1);
        final y =
            size.height -
            (point.usage.inSeconds / maxSeconds) * size.height * 0.82;

        final labelSpan = TextSpan(
          text: _duration(point.usage),
          style: TextStyle(
            color: lineColor,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        );
        final labelTp = TextPainter(
          text: labelSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final labelX = (x - labelTp.width / 2).clamp(
          0.0,
          size.width - labelTp.width,
        );
        final labelY = (y - 14).clamp(0.0, size.height - 14);
        labelTp.paint(canvas, Offset(labelX, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}

class _OpensHistoryPainter extends CustomPainter {
  final List<int> dailyCounts;
  final List<DateTime> days;
  final Color barColor;
  final Color gridColor;

  const _OpensHistoryPainter({
    required this.dailyCounts,
    required this.days,
    required this.barColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withOpacity(0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final maxCount = math.max(1, dailyCounts.fold<int>(0, math.max));

    // Draw Y-axis labels
    final textStyle = TextStyle(
      color: gridColor.withOpacity(0.9),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    void drawCountLabel(String text, double y) {
      final span = TextSpan(text: text, style: textStyle);
      final tp = TextPainter(text: span, textDirection: ui.TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(4, (y - 12).clamp(0, size.height - 14)));
    }

    drawCountLabel('$maxCount', 0);
    drawCountLabel('${(maxCount / 2).round()}', size.height / 2);
    drawCountLabel('0', size.height);

    if (dailyCounts.isEmpty) return;

    final n = dailyCounts.length;
    final slotWidth = size.width / n;
    final barWidth = (slotWidth * 0.55).clamp(3.0, 24.0);

    for (var i = 0; i < n; i++) {
      final count = dailyCounts[i];
      final xCenter = slotWidth * i + slotWidth / 2;
      final barHeight = (count / maxCount) * size.height * 0.80;
      final top = size.height - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          xCenter - barWidth / 2,
          top,
          barWidth,
          barHeight.clamp(2.0, size.height),
        ),
        const Radius.circular(5),
      );

      final barPaint = Paint()
        ..color = count > 0 ? barColor : barColor.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, barPaint);

      // Label above bar for 7d or 14d
      if (n <= 14 && count > 0) {
        final labelSpan = TextSpan(
          text: '$count',
          style: TextStyle(
            color: barColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        final labelTp = TextPainter(
          text: labelSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final labelX = (xCenter - labelTp.width / 2).clamp(
          0.0,
          size.width - labelTp.width,
        );
        final labelY = (top - 14).clamp(0.0, size.height - 14);
        labelTp.paint(canvas, Offset(labelX, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OpensHistoryPainter oldDelegate) =>
      oldDelegate.dailyCounts != dailyCounts ||
      oldDelegate.barColor != barColor;
}

class _OpensHistoryCard extends StatelessWidget {
  final _AppDailyOpensHistory data;

  const _OpensHistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.days;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Average',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          data.averageOpens.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'opens/day',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TrendBadge(value: data.trend),
                  const SizedBox(height: 4),
                  Text(
                    '${data.totalOpens} total',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _OpensHistoryPainter(
                dailyCounts: data.dailyCounts,
                days: data.days,
                barColor: primary,
                gridColor: Theme.of(context).dividerColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          if (days.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(days.first),
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  DateFormat('MMM d').format(days[days.length ~/ 2]),
                  style: const TextStyle(fontSize: 10),
                ),
                Text(
                  DateFormat('MMM d').format(days.last),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final AppCategory category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _categoryLabel(category),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrendText extends StatelessWidget {
  final double? value;

  const _TrendText({required this.value});

  @override
  Widget build(BuildContext context) {
    final change = value;
    if (change == null) {
      return Text(
        'No comparison',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w300,
        ),
      );
    }
    final up = change > 0;
    final down = change < 0;
    final color = up
        ? AppTheme.danger
        : down
        ? AppTheme.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      '${up
          ? '↑'
          : down
          ? '↓'
          : '–'} ${change.abs().round()}%',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double? value;

  const _TrendBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final change = value;
    if (change == null) {
      return Text(
        'Not enough history',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      );
    }
    final up = change > 0;
    final down = change < 0;
    final color = up
        ? AppTheme.danger
        : down
        ? AppTheme.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '${up
            ? 'Up'
            : down
            ? 'Down'
            : 'Same'} ${change.abs().round()}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onTap;

  const _MessageCard({required this.text, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onTap, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

Color _categoryColor(AppCategory category) {
  switch (category) {
    case AppCategory.productive:
      return AppTheme.success;
    case AppCategory.neutral:
      return AppTheme.mist;
    case AppCategory.distracting:
      return AppTheme.danger;
  }
}

IconData _categoryIcon(AppCategory category) {
  switch (category) {
    case AppCategory.productive:
      return Icons.check_circle_outline_rounded;
    case AppCategory.neutral:
      return Icons.remove_circle_outline_rounded;
    case AppCategory.distracting:
      return Icons.warning_amber_rounded;
  }
}

String _categoryLabel(AppCategory category) {
  switch (category) {
    case AppCategory.productive:
      return 'Productive';
    case AppCategory.neutral:
      return 'Neutral';
    case AppCategory.distracting:
      return 'Distracting';
  }
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${value.inMinutes}m';
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

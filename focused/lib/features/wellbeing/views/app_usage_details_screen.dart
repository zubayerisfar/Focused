import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_category.dart';
import '../models/daily_usage_metrics.dart';
import '../models/hourly_usage_summary.dart';
import '../models/usage_access_status.dart';
import '../providers/usage_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';

enum _UsageViewMode { daily, hourly }

class AppUsageDetailsScreen extends StatefulWidget {
  const AppUsageDetailsScreen({super.key});

  @override
  State<AppUsageDetailsScreen> createState() => _AppUsageDetailsScreenState();
}

class _AppUsageDetailsScreenState extends State<AppUsageDetailsScreen> {
  _UsageViewMode _mode = _UsageViewMode.daily;
  late Future<List<DailyUsageMetrics>> _dailyFuture;
  late Future<_OpenSummary> _opensFuture;

  @override
  void initState() {
    super.initState();
    final usage = context.read<UsageProvider>();
    _dailyFuture = usage.loadDailyUsageHistory(days: 7);
    _opensFuture = _loadOpenSummary(usage);
  }

  Future<void> _refresh() async {
    final usage = context.read<UsageProvider>();
    await usage.refreshPermissionAndUsage(force: true);
    if (!mounted) return;
    setState(() {
      _dailyFuture = usage.loadDailyUsageHistory(days: 7);
      _opensFuture = _loadOpenSummary(usage);
    });
  }

  Future<_OpenSummary> _loadOpenSummary(UsageProvider usage) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final opens = await usage.loadAppOpenEvents(start: start, end: now);
    var distracting = 0;
    for (final event in opens) {
      if (usage.getAppCategory(event.appId) == AppCategory.distracting) {
        distracting++;
      }
    }
    return _OpenSummary(total: opens.length, distracting: distracting);
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final summary = usage.todaySummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: usage.isRefreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !usage.hasUsageAccess
          ? _UnavailableBody(
              status: usage.accessStatus,
              onAction: () => context.push('/wellbeing/permission'),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                children: [
                  _UsageTotal(
                    duration: summary?.totalUsage,
                    change: usage.todayVsYesterdayPercent,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_OpenSummary>(
                    future: _opensFuture,
                    builder: (context, snapshot) {
                      return _OpenSummaryCard(summary: snapshot.data);
                    },
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<_UsageViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: _UsageViewMode.daily,
                        label: Text('Daily'),
                        icon: Icon(Icons.calendar_view_week_rounded),
                      ),
                      ButtonSegment(
                        value: _UsageViewMode.hourly,
                        label: Text('Hourly'),
                        icon: Icon(Icons.schedule_rounded),
                      ),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      setState(() => _mode = selection.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_mode == _UsageViewMode.hourly) ...[
                    Text(
                      'Usage through the day',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See when your screen time builds up during the day.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HourlyLineChart(values: summary?.hourlyUsage ?? const []),
                  ] else ...[
                    Text(
                      'Last 7 days',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily screen time measured on this device.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<List<DailyUsageMetrics>>(
                      future: _dailyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return _SimpleMessage(
                            text: 'Could not load daily usage history.',
                            onRetry: () {
                              setState(() {
                                _dailyFuture = context
                                    .read<UsageProvider>()
                                    .loadDailyUsageHistory(days: 7);
                              });
                            },
                          );
                        }
                        return _DailyUsageChart(values: snapshot.data ?? const []);
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Apps',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _AppActivityList(provider: usage),
                ],
              ),
            ),
    );
  }
}

class _OpenSummary {
  const _OpenSummary({required this.total, required this.distracting});
  final int total;
  final int distracting;
}

class _OpenSummaryCard extends StatelessWidget {
  const _OpenSummaryCard({required this.summary});
  final _OpenSummary? summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OpenMetric(
              label: 'App opens',
              value: summary == null ? '—' : '${summary!.total}',
              icon: Icons.touch_app_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 42,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _OpenMetric(
              label: 'Distracting opens',
              value: summary == null ? '—' : '${summary!.distracting}',
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenMetric extends StatelessWidget {
  const _OpenMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsageTotal extends StatelessWidget {
  final Duration? duration;
  final double? change;

  const _UsageTotal({required this.duration, required this.change});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  duration == null ? '—' : _formatDuration(duration!),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          _ChangeBadge(value: change, showNeutral: true),
        ],
      ),
    );
  }
}

class _DailyUsageChart extends StatelessWidget {
  const _DailyUsageChart({required this.values});

  final List<DailyUsageMetrics> values;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = values.fold<int>(
      0,
      (maximum, item) => item.totalUsage.inSeconds > maximum
          ? item.totalUsage.inSeconds
          : maximum,
    );
    return Container(
      height: 245,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: values.isEmpty
          ? const Center(child: Text('No measured daily usage yet.'))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values.map((day) {
                final fraction = maxSeconds <= 0
                    ? 0.0
                    : day.totalUsage.inSeconds / maxSeconds;
                final label = _weekdayLabel(day.day.weekday);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          day.measured ? _shortDuration(day.totalUsage) : '—',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: day.measured
                                  ? (fraction < 0.025 ? 0.025 : fraction)
                                  : 0.025,
                              child: Container(
                                width: 22,
                                decoration: BoxDecoration(
                                  color: day.measured
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).dividerColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(label, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
    );
  }
}

class _SimpleMessage extends StatelessWidget {
  const _SimpleMessage({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

class _HourlyLineChart extends StatelessWidget {
  final List<HourlyUsageSummary> values;

  const _HourlyLineChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final minutes = List<double>.filled(24, 0);
    for (final item in values) {
      final hour = item.hourStart.hour;
      if (hour >= 0 && hour < 24) {
        minutes[hour] = item.totalUsage.inSeconds / 60;
      }
    }

    return Container(
      height: 245,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _HourlyLinePainter(
                values: minutes,
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
                fillColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.10),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12a', style: TextStyle(fontSize: 10)),
              Text('6a', style: TextStyle(fontSize: 10)),
              Text('12p', style: TextStyle(fontSize: 10)),
              Text('6p', style: TextStyle(fontSize: 10)),
              Text('11p', style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyLinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;
  final Color fillColor;

  const _HourlyLinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withOpacity(0.72)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.isEmpty) return;
    final maxValue = math.max(1.0, values.reduce(math.max));
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? 0.0
          : size.width * index / (values.length - 1);
      final y = size.height - (values[index] / maxValue) * size.height * 0.9;
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);

    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    for (var index = 0; index < points.length; index += 3) {
      canvas.drawCircle(points[index], 2.7, dotPaint);
    }
    canvas.drawCircle(points.last, 2.7, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HourlyLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _AppActivityList extends StatelessWidget {
  final UsageProvider provider;

  const _AppActivityList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final entries = provider.topAppEntriesToday(
      limit: provider.todayRecords.length,
    );

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('No app activity measured today.'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final change = provider.getAppChangePercentById(entry.appId);
          final category = provider.getAppCategory(entry.appId);

          return Column(
            children: [
              InkWell(
                onTap: () {
                  final id = Uri.encodeComponent(entry.appId);
                  final name = Uri.encodeQueryComponent(entry.appName);
                  context.push('/wellbeing/app/$id?name=$name');
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                  child: Row(
                    children: [
                      AppIcon(
                        iconBytes: entry.iconBytes,
                        appName: entry.appName,
                        size: 38,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    entry.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (change != null) ...[
                                  const SizedBox(width: 7),
                                  _ChangeBadge(value: change),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _categoryLabel(category),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDuration(entry.duration),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  indent: 66,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final double? value;
  final bool showNeutral;

  const _ChangeBadge({required this.value, this.showNeutral = false});

  @override
  Widget build(BuildContext context) {
    final change = value;
    if (change == null) {
      if (!showNeutral) return const SizedBox.shrink();
      return Text(
        'No comparison',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final icon = up
        ? Icons.arrow_upward_rounded
        : down
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 2),
          Text(
            '${change.abs().round()}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableBody extends StatelessWidget {
  final UsageAccessStatus status;
  final VoidCallback onAction;

  const _UnavailableBody({required this.status, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final unsupported = status == UsageAccessStatus.unsupported;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unsupported
                  ? Icons.desktop_windows_outlined
                  : Icons.query_stats_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              unsupported
                  ? 'App activity is unavailable here'
                  : 'Allow app usage access',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              unsupported
                  ? 'This screen currently uses Android app-usage data.'
                  : 'Focused needs Android Usage Access to show your app activity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w300,
              ),
            ),
            if (!unsupported) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(AppCategory value) {
  switch (value) {
    case AppCategory.productive:
      return 'Productive';
    case AppCategory.neutral:
      return 'Neutral';
    case AppCategory.distracting:
      return 'Distracting';
  }
}

String _weekdayLabel(int weekday) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[(weekday - 1).clamp(0, 6).toInt()];
}

String _shortDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0 ? '${duration.inHours}h' : '${duration.inHours}h${minutes}m';
  }
  return '${duration.inMinutes}m';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

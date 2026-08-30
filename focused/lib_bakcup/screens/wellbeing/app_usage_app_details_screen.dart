import 'dart:async';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_category.dart';
import '../../models/app_usage_history_point.dart';
import '../../models/usage_data_coverage.dart';
import '../../models/usage_data_provenance.dart';
import '../../providers/usage_provider.dart';
import '../../widgets/app_icon.dart';

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

class _AppUsageAppDetailsScreenState extends State<AppUsageAppDetailsScreen> {
  int _days = 7;
  late DateTime _endDay;
  late Future<List<AppUsageHistoryPoint>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _endDay = _startOfDay(DateTime.now());
    _historyFuture = _load();
  }

  Future<List<AppUsageHistoryPoint>> _load() {
    return context.read<UsageProvider>().loadAppUsageHistory(
          widget.appId,
          days: _days,
          endDay: _endDay,
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
    });
  }

  void _changeDays(int days) {
    if (_days == days) {
      return;
    }

    setState(() {
      _days = days;
      _historyFuture = _load();
    });
  }

  void _goEarlier() {
    setState(() {
      _endDay = DateTime(
        _endDay.year,
        _endDay.month,
        _endDay.day - _days,
      );
      _historyFuture = _load();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsageProvider>();
    final appName = provider.resolveDisplayName(
      widget.appId,
      fallback: provider.resolveAppName(
        widget.appId,
        fallback: widget.initialAppName,
      ),
    );
    final metadata = provider.getAppMetadata(widget.appId);
    final category = provider.getAppCategory(widget.appId);
    final today = _startOfDay(DateTime.now());
    final atLatestRange = !_endDay.isBefore(today);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _cleanAppName(appName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload history',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<AppUsageHistoryPoint>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _HistoryError(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final points =
              snapshot.data ?? const <AppUsageHistoryPoint>[];

          return RefreshIndicator(
            onRefresh: () async {
              await provider.refreshPermissionAndUsage(force: true);
              if (!mounted) {
                return;
              }
              _reload();
              await _historyFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                _AppHero(
                  appId: widget.appId,
                  appName: appName,
                  iconBytes: metadata?.iconBytes,
                  category: category,
                  points: points,
                  provider: provider,
                ),
                const SizedBox(height: 22),
                _CategoryCard(
                  category: category,
                  onChanged: (value) async {
                    try {
                      await provider.setAppCategory(
                        widget.appId,
                        value,
                      );
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save this app classification.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 28),
                _HistoryHeader(
                  days: _days,
                  endDay: _endDay,
                  onDaysChanged: _changeDays,
                  onEarlier: _goEarlier,
                  onNewer: atLatestRange ? null : _goNewer,
                ),
                const SizedBox(height: 12),
                _UsageHistoryCard(
                  points: points,
                  trendPercent: provider.usageTrendPercent(points),
                ),
                const SizedBox(height: 22),
                _DailyBreakdown(points: points),
                const SizedBox(height: 22),
                _StorageNote(points: points),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppHero extends StatelessWidget {
  final String appId;
  final String appName;
  final Uint8List? iconBytes;
  final AppCategory category;
  final List<AppUsageHistoryPoint> points;
  final UsageProvider provider;

  const _AppHero({
    required this.appId,
    required this.appName,
    required this.iconBytes,
    required this.category,
    required this.points,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final measured = points.where((point) => point.measured).toList();
    final latest = measured.isEmpty ? null : measured.last;

    AppUsageHistoryPoint? previous;
    if (latest != null) {
      final latestIndex = points.indexOf(latest);
      if (latestIndex > 0) {
        previous = points[latestIndex - 1];
      }
    }

    final comparison = latest == null
        ? null
        : latest.completeDay
            ? (previous == null
                ? null
                : provider.usageComparisonPercent(latest, previous))
            : provider.getAppChangePercentById(appId);
    final trend = provider.usageTrendPercent(points);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(
                iconBytes: iconBytes,
                appName: _cleanAppName(appName),
                size: 58,
                borderRadius: 18,
                fallbackBackground:
                    _categoryColor(context, category).withOpacity(0.12),
                fallbackForeground: _categoryColor(context, category),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanAppName(appName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _categoryLabel(category),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _categoryColor(context, category),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Latest day',
                  value: latest == null
                      ? 'No data'
                      : _formatDuration(latest.usage),
                  supporting: latest == null
                      ? 'No stored snapshot'
                      : DateFormat('EEE, MMM d').format(latest.day),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: latest != null && !latest.completeDay
                      ? 'Vs same time yesterday'
                      : 'Vs previous day',
                  value: _percentValue(comparison),
                  supporting: _comparisonMeaning(comparison),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Trend',
                  value: _trendWord(trend),
                  supporting: _trendSupporting(trend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final String supporting;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.supporting,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            supporting,
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

class _CategoryCard extends StatelessWidget {
  final AppCategory category;
  final ValueChanged<AppCategory> onChanged;

  const _CategoryCard({
    required this.category,
    required this.onChanged,
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
          Text(
            'How should Focused treat this app?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'This classification is stored locally and is used by daily wellbeing and focus-interruption calculations.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppCategory.values.map((value) {
              return ChoiceChip(
                selected: category == value,
                avatar: Icon(
                  _categoryIcon(value),
                  size: 18,
                ),
                label: Text(_categoryLabel(value)),
                onSelected: (_) => onChanged(value),
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
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onEarlier;
  final VoidCallback? onNewer;

  const _HistoryHeader({
    required this.days,
    required this.endDay,
    required this.onDaysChanged,
    required this.onEarlier,
    required this.onNewer,
  });

  @override
  Widget build(BuildContext context) {
    final startDay = DateTime(
      endDay.year,
      endDay.month,
      endDay.day - (days - 1),
    );

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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('MMM d').format(startDay)} – ${DateFormat('MMM d, y').format(endDay)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Earlier period',
              onPressed: onEarlier,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Newer period',
              onPressed: onNewer,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [7, 14, 30, 90].map((value) {
              final selected = days == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text('${value}d'),
                  onSelected: (_) => onDaysChanged(value),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _UsageHistoryCard extends StatelessWidget {
  final List<AppUsageHistoryPoint> points;
  final double? trendPercent;

  const _UsageHistoryCard({
    required this.points,
    required this.trendPercent,
  });

  @override
  Widget build(BuildContext context) {
    final coverage = UsageDataCoverage.fromMeasurements(
      points.map(
        (point) => UsageCoverageSample(
          provenance: point.provenance,
          completeDay: point.completeDay,
        ),
      ),
    );
    final maxSeconds = points.fold<int>(
      0,
      (maxValue, point) => math.max(
        maxValue,
        point.measured ? point.usage.inSeconds : 0,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _trendHeadline(trendPercent),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${coverage.completeDays}/${coverage.totalDays} complete',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _UsageHistoryPainter(
                points: points,
                maxSeconds: math.max(1, maxSeconds),
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
                missingColor: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ChartAxisLabels(points: points),
        ],
      ),
    );
  }
}

class _ChartAxisLabels extends StatelessWidget {
  final List<AppUsageHistoryPoint> points;

  const _ChartAxisLabels({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final middle = points[points.length ~/ 2];

    return Row(
      children: [
        Expanded(
          child: Text(
            DateFormat('MMM d').format(points.first.day),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Text(
            DateFormat('MMM d').format(middle.day),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Text(
            DateFormat('MMM d').format(points.last.day),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _UsageHistoryPainter extends CustomPainter {
  final List<AppUsageHistoryPoint> points;
  final int maxSeconds;
  final Color lineColor;
  final Color gridColor;
  final Color missingColor;

  const _UsageHistoryPainter({
    required this.points,
    required this.maxSeconds,
    required this.lineColor,
    required this.gridColor,
    required this.missingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.7)
      ..strokeWidth = 1;

    for (var index = 0; index <= 4; index++) {
      final y = size.height * index / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (points.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final missingPaint = Paint()
      ..color = missingColor
      ..style = PaintingStyle.fill;

    Offset? previous;

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);

      if (!point.measured) {
        canvas.drawCircle(
          Offset(x, size.height - 3),
          3,
          missingPaint,
        );
        previous = null;
        continue;
      }

      final ratio =
          (point.usage.inSeconds / maxSeconds).clamp(0.0, 1.0);
      final y = size.height - (size.height * ratio);
      final current = Offset(x, y);

      if (previous != null) {
        canvas.drawLine(previous, current, linePaint);
      }

      canvas.drawCircle(current, 4, pointPaint);
      previous = current;
    }
  }

  @override
  bool shouldRepaint(covariant _UsageHistoryPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxSeconds != maxSeconds ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.missingColor != missingColor;
  }
}

class _DailyBreakdown extends StatelessWidget {
  final List<AppUsageHistoryPoint> points;

  const _DailyBreakdown({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = points.reversed.take(14).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily values',
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
            children: List.generate(visible.length, (index) {
              final point = visible[index];
              return Column(
                children: [
                  ListTile(
                    leading: Icon(_provenanceIcon(point.provenance)),
                    title: Text(
                      DateFormat('EEEE, MMM d').format(point.day),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      point.measured
                          ? '${point.provenance.label}${point.completeDay ? '' : ' • Partial day'}'
                          : 'No trustworthy measurement for this day',
                    ),
                    trailing: Text(
                      point.measured
                          ? _formatDuration(point.usage)
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (index != visible.length - 1)
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

class _StorageNote extends StatelessWidget {
  final List<AppUsageHistoryPoint> points;

  const _StorageNote({required this.points});

  @override
  Widget build(BuildContext context) {
    final coverage = UsageDataCoverage.fromMeasurements(
      points.map(
        (point) => UsageCoverageSample(
          provenance: point.provenance,
          completeDay: point.completeDay,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.storage_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Coverage ${coverage.measuredDays}/${coverage.totalDays} days (${coverage.percent}%). '
              'Measured today: ${coverage.liveAndroidDays}. Android history: ${coverage.androidHistoryDays}. '
              'Stored by Focused: ${coverage.focusedStorageDays}. Partial: ${coverage.partialDays}. Missing: ${coverage.missingDays}. '
              '${coverage.isSufficientForTrend ? 'This range has enough coverage for a trend.' : 'Focused will withhold the trend until enough days are measured.'} '
              'Missing days are never treated as zero usage.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HistoryError({
    required this.message,
    required this.onRetry,
  });

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
              'Could not load app history',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
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

IconData _categoryIcon(AppCategory category) {
  switch (category) {
    case AppCategory.productive:
      return Icons.auto_awesome_rounded;
    case AppCategory.neutral:
      return Icons.horizontal_rule_rounded;
    case AppCategory.distracting:
      return Icons.notifications_active_outlined;
  }
}

Color _categoryColor(
  BuildContext context,
  AppCategory category,
) {
  switch (category) {
    case AppCategory.productive:
      return const Color(0xFF5E8F78);
    case AppCategory.neutral:
      return Theme.of(context).colorScheme.secondary;
    case AppCategory.distracting:
      return const Color(0xFFB76E6E);
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

String _percentValue(double? value) {
  if (value == null) {
    return '—';
  }

  final rounded = value.abs().round();
  if (rounded == 0) {
    return '0%';
  }

  return '${value > 0 ? '+' : '-'}$rounded%';
}

String _comparisonMeaning(double? value) {
  if (value == null) {
    return 'Not comparable';
  }

  if (value.abs() < 1) {
    return 'About the same';
  }

  return value < 0 ? 'Less usage' : 'More usage';
}

String _trendWord(double? value) {
  if (value == null) {
    return 'Learning';
  }

  if (value.abs() <= 5) {
    return 'Stable';
  }

  return value < 0 ? 'Going down' : 'Going up';
}

String _trendSupporting(double? value) {
  if (value == null) {
    return 'Need more days';
  }

  if (value.abs() <= 5) {
    return 'Within ±5%';
  }

  return '${value.abs().round()}% ${value < 0 ? 'lower' : 'higher'}';
}

String _trendHeadline(double? value) {
  if (value == null) {
    return 'Trend will appear after more measured days';
  }

  if (value.abs() <= 5) {
    return 'Usage is staying fairly steady';
  }

  if (value < 0) {
    return 'Usage is trending down';
  }

  return 'Usage is trending up';
}

String _cleanAppName(String value) {
  if (value.trim().isEmpty) {
    return 'Unknown app';
  }

  if (!value.contains('.')) {
    return value;
  }

  final last = value.split('.').last;
  if (last.isEmpty) {
    return value;
  }

  return '${last[0].toUpperCase()}${last.substring(1)}';
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

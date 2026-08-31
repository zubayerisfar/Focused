import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_category.dart';
import '../../models/app_usage_history_point.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';
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

class _AppUsageAppDetailsScreenState
    extends State<AppUsageAppDetailsScreen> {
  int _days = 7;
  late DateTime _endDay;
  late Future<List<AppUsageHistoryPoint>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _endDay = _startOfDay(DateTime.now());
    _historyFuture = _load();
    unawaited(
      context.read<UsageProvider>().ensureAppMetadata(widget.appId),
    );
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
    if (_days == days) return;
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
                latestUsage:
                    latest?.measured == true ? latest!.usage : null,
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
                onDaysChanged: _changeDays,
                onEarlier: _goEarlier,
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
            ],
          );
        },
      ),
    );
  }

  bool get _isCurrentWindow =>
      !_endDay.isBefore(_startOfDay(DateTime.now()));
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

  const _CategoryCard({
    required this.selected,
    required this.onChanged,
  });

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
                  color: selectedNow ? color : null,
                ),
                label: Text(_categoryLabel(value)),
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
    final start = DateTime(endDay.year, endDay.month, endDay.day - (days - 1));
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
            return ChoiceChip(
              showCheckmark: false,
              selected: days == value,
              label: Text('${value}d'),
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
    final averageSeconds = measured.fold<int>(
          0,
          (sum, point) => sum + point.usage.inSeconds,
        ) ~/
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
                fillColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.09),
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

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (!point.measured) {
        finishSegment();
        continue;
      }

      final x = points.length == 1
          ? 0.0
          : size.width * index / (points.length - 1);
      final y = size.height -
          (point.usage.inSeconds / maxSeconds) * size.height * 0.88;
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
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
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
      '${up ? '↑' : down ? '↓' : '–'} ${change.abs().round()}%',
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
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
        '${up ? 'Up' : down ? 'Down' : 'Same'} ${change.abs().round()}%',
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

  const _MessageCard({
    required this.text,
    this.action,
    this.onTap,
  });

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

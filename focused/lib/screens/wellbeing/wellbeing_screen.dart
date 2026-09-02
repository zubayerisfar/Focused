import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_usage_app_entry.dart';
import '../../models/daily_usage_metrics.dart';
import '../../models/focus_analysis_result.dart';
import '../../models/usage_access_status.dart';
import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final focus = context.watch<FocusProvider>();

    if (usage.accessStatus == UsageAccessStatus.checking &&
        usage.todaySummary == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final supported = usage.accessStatus != UsageAccessStatus.unsupported;
    final granted = usage.hasUsageAccess;
    final latestAnalysis = _latestAnalysis(focus, usage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen time & focus'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: usage.isRefreshing
                ? null
                : () => usage.refreshPermissionAndUsage(force: true),
            icon: usage.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(FontAwesomeIcons.arrowsRotate, size: 17),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => usage.refreshPermissionAndUsage(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          children: [
            if (!granted)
              _UsageAccessCard(
                supported: supported,
                onTap: supported
                    ? () => context.push('/wellbeing/permission')
                    : null,
              ),
            if (!granted) const SizedBox(height: 18),
            _InteractiveUsagePie(
              totalUsage: usage.todaySummary?.totalUsage,
              comparisonPercent: usage.todayVsYesterdayPercent,
              entries: usage.topAppEntriesToday(limit: 5),
              onOpenApp: (entry) {
                final id = Uri.encodeComponent(entry.appId);
                final name = Uri.encodeQueryComponent(entry.appName);
                context.push('/wellbeing/app/$id?name=$name');
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _EntryCard(
                    icon: FontAwesomeIcons.chartPie,
                    title: 'Overall summary',
                    subtitle: 'Focus, screen time and distractions',
                    accent: AppTheme.lavender,
                    onTap: () => context.push('/wellbeing/summary'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EntryCard(
                    icon: FontAwesomeIcons.chartColumn,
                    title: 'App usage stats',
                    subtitle: 'Apps, trends and hourly activity',
                    accent: Theme.of(context).colorScheme.primary,
                    onTap: () => context.push('/wellbeing/app-usage'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _EntryCard(
              icon: FontAwesomeIcons.hourglassHalf,
              title: 'App Limits & Timers',
              subtitle: 'Set daily screen time limits and over-usage warnings',
              accent: const Color(0xFFF59E0B),
              onTap: () => context.push('/wellbeing/limits'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Focus interruptions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/wellbeing/focus-interruptions'),
                  child: const Text('Details'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FocusInterruptionCard(analysis: latestAnalysis),
            const SizedBox(height: 28),
            Text(
              'Last 7 days',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap a day to see its screen time, focus and interruption details.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            const _LastSevenDaysCard(),
          ],
        ),
      ),
    );
  }
}

class _InteractiveUsagePie extends StatelessWidget {
  const _InteractiveUsagePie({
    required this.totalUsage,
    required this.comparisonPercent,
    required this.entries,
    required this.onOpenApp,
  });

  final Duration? totalUsage;
  final double? comparisonPercent;
  final List<AppUsageAppEntry> entries;
  final ValueChanged<AppUsageAppEntry> onOpenApp;

  @override
  Widget build(BuildContext context) {
    final values = entries.take(4).toList(growable: false);
    final colors = _pieColors(context);

    final visibleTotal = values.fold<int>(
      0,
      (sum, entry) => sum + entry.duration.inMilliseconds,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(220),
                  painter: _SimpleUsageDonutPainter(
                    entries: values,
                    colors: colors,
                    trackColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        totalUsage == null ? '—' : _duration(totalUsage!),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PieTrend(value: comparisonPercent),
                      const SizedBox(height: 1),
                      Text(
                        'vs yesterday',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (values.isEmpty)
            Text(
              'No app usage measured yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            _UsageLegendList(
              entries: values,
              colors: colors,
              totalMilliseconds: visibleTotal,
              onOpenApp: onOpenApp,
            ),
        ],
      ),
    );
  }
}

class _SimpleUsageDonutPainter extends CustomPainter {
  const _SimpleUsageDonutPainter({
    required this.entries,
    required this.colors,
    required this.trackColor,
  });

  final List<AppUsageAppEntry> entries;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final radius = math.min(size.width, size.height) / 2 - 12;

    final rect = Rect.fromCircle(center: center, radius: radius);

    const strokeWidth = 28.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(center, radius, trackPaint);

    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.duration.inMilliseconds,
    );

    if (total <= 0) return;

    var start = -math.pi / 2;
    const gap = 0.035;

    for (var index = 0; index < entries.length; index++) {
      final fraction = entries[index].duration.inMilliseconds / total;

      final rawSweep = fraction * math.pi * 2;

      final sweep = math.max(0.0, rawSweep - gap);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = colors[index % colors.length];

      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);

      start += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleUsageDonutPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.trackColor != trackColor;
  }
}

class _UsageLegendList extends StatelessWidget {
  const _UsageLegendList({
    required this.entries,
    required this.colors,
    required this.totalMilliseconds,
    required this.onOpenApp,
  });

  final List<AppUsageAppEntry> entries;
  final List<Color> colors;
  final int totalMilliseconds;
  final ValueChanged<AppUsageAppEntry> onOpenApp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];

        final percent = totalMilliseconds <= 0
            ? 0
            : (entry.duration.inMilliseconds / totalMilliseconds * 100).round();

        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpenApp(entry),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppIcon(
                      iconBytes: entry.iconBytes,
                      appName: entry.appName,
                      size: 34,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        entry.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _duration(entry.duration),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
            if (index != entries.length - 1)
              Divider(
                height: 1,
                indent: 54,
                color: Theme.of(context).dividerColor,
              ),
          ],
        );
      }),
    );
  }
}

class _PieTrend extends StatelessWidget {
  const _PieTrend({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Text('—', style: TextStyle(fontWeight: FontWeight.w700));
    }

    final down = value! < -0.5;
    final up = value! > 0.5;

    final color = down
        ? AppTheme.success
        : up
        ? AppTheme.danger
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(
          down
              ? FontAwesomeIcons.arrowDown
              : up
              ? FontAwesomeIcons.arrowUp
              : FontAwesomeIcons.minus,
          size: 10,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${value!.abs().round()}%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LastSevenDaysCard extends StatefulWidget {
  const _LastSevenDaysCard();

  @override
  State<_LastSevenDaysCard> createState() => _LastSevenDaysCardState();
}

class _LastSevenDaysCardState extends State<_LastSevenDaysCard> {
  late Future<List<DailyUsageMetrics>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<UsageProvider>().loadDailyUsageHistory(
      days: 7,
      includeMissingDays: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    return FutureBuilder<List<DailyUsageMetrics>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 92,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final days = (snapshot.data ?? const <DailyUsageMetrics>[]).reversed
            .toList(growable: false);
        if (days.isEmpty) {
          return const Text('No recent daily measurements yet.');
        }
        return Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(days.length, (index) {
              final day = days[index];
              final focused = focus.focusedDurationForDate(day.day);
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        DateFormat('d').format(day.day),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      DateFormat('EEE, MMM d').format(day.day),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Screen ${day.measured ? _duration(day.totalUsage) : '—'}  •  Focus ${_duration(focused)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final raw = DateFormat('yyyy-MM-dd').format(day.day);
                      context.push('/wellbeing/day?date=$raw');
                    },
                  ),
                  if (index != days.length - 1)
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Theme.of(context).dividerColor,
                    ),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

class _UsageAccessCard extends StatelessWidget {
  const _UsageAccessCard({required this.supported, required this.onTap});
  final bool supported;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const FaIcon(FontAwesomeIcons.shieldHalved, size: 18),
        title: Text(
          supported
              ? 'App usage access needed'
              : 'App usage is unavailable here',
        ),
        subtitle: Text(
          supported
              ? 'Allow Focused to read Android app-usage statistics.'
              : 'This feature currently requires Android.',
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FaIcon(icon, color: accent, size: 19),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusInterruptionCard extends StatelessWidget {
  const _FocusInterruptionCard({required this.analysis});
  final FocusAnalysisResult? analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (analysis == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleInfo, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No analyzed focus session yet. Finish a focus session and Focused will show interruption details here.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${analysis!.focusQuality.round()}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${analysis!.interruptionCount} interruption${analysis!.interruptionCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_duration(analysis!.distractedDuration)} distracted during the latest analyzed focus session.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

FocusAnalysisResult? _latestAnalysis(FocusProvider focus, UsageProvider usage) {
  final live = usage.focusAnalysisResult;
  if (live != null) return live;
  for (final session in focus.sessionHistory) {
    final saved = usage.storedFocusAnalyses[session.id];
    if (saved != null) return saved;
  }
  return null;
}

List<Color> _pieColors(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return [
    scheme.primary,
    AppTheme.lavender,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.mist,
  ];
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  if (value.inMinutes > 0) return '${value.inMinutes}m';
  return '${value.inSeconds}s';
}

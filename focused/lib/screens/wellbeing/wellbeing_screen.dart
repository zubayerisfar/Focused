import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_usage_app_entry.dart';
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                : const Icon(Icons.refresh_rounded),
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
            _InteractiveUsageHero(
              totalUsage: usage.todaySummary?.totalUsage,
              comparisonPercent: usage.todayVsYesterdayPercent,
              entries: usage.topAppEntriesToday(limit: 8),
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
                    icon: Icons.dashboard_outlined,
                    title: 'Overall summary',
                    subtitle: 'Focus, screen time and distractions',
                    accent: AppTheme.lavender,
                    onTap: () => context.push('/wellbeing/summary'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EntryCard(
                    icon: Icons.query_stats_rounded,
                    title: 'App usage stats',
                    subtitle: 'Apps, trends and hourly activity',
                    accent: Theme.of(context).colorScheme.primary,
                    onTap: () => context.push('/wellbeing/app-usage'),
                  ),
                ),
              ],
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
                if (latestAnalysis != null)
                  TextButton(
                    onPressed: () =>
                        context.push('/wellbeing/focus-interruptions'),
                    child: const Text('Details'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _FocusInterruptionCard(analysis: latestAnalysis),
          ],
        ),
      ),
    );
  }
}

class _InteractiveUsageHero extends StatelessWidget {
  final Duration? totalUsage;
  final double? comparisonPercent;
  final List<AppUsageAppEntry> entries;
  final ValueChanged<AppUsageAppEntry> onOpenApp;

  const _InteractiveUsageHero({
    required this.totalUsage,
    required this.comparisonPercent,
    required this.entries,
    required this.onOpenApp,
  });

  static const _size = 252.0;
  static const _stroke = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = _ringColors(context);
    final appTotal = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.duration.inMilliseconds,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: appTotal <= 0
                  ? null
                  : (details) {
                      final selected = _entryForTap(
                        details.localPosition,
                        entries,
                        appTotal,
                      );
                      if (selected == null) return;
                      _showAppSlice(context, selected);
                    },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(_size),
                    painter: _UsageRingPainter(
                      entries: entries,
                      total: appTotal,
                      colors: colors,
                      trackColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      strokeWidth: _stroke,
                    ),
                  ),
                  SizedBox(
                    width: 154,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TODAY',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          totalUsage == null ? '—' : _duration(totalUsage!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _RingTrend(value: comparisonPercent),
                        const SizedBox(height: 2),
                        Text(
                          'vs yesterday',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            entries.isEmpty
                ? 'No app usage measured yet.'
                : 'Tap a ring segment to see the app.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  AppUsageAppEntry? _entryForTap(
    Offset position,
    List<AppUsageAppEntry> values,
    int total,
  ) {
    const center = Offset(_size / 2, _size / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final outerRadius = _size / 2;
    final innerRadius = outerRadius - _stroke - 8;

    if (radius < innerRadius || radius > outerRadius + 4) {
      return null;
    }

    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final fraction = angle / (math.pi * 2);

    var cumulative = 0.0;
    for (final entry in values) {
      cumulative += entry.duration.inMilliseconds / total;
      if (fraction <= cumulative) return entry;
    }
    return values.isEmpty ? null : values.last;
  }

  Future<void> _showAppSlice(
    BuildContext context,
    AppUsageAppEntry entry,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  iconBytes: entry.iconBytes,
                  appName: entry.appName,
                  size: 58,
                  borderRadius: 18,
                ),
                const SizedBox(height: 12),
                Text(
                  entry.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _duration(entry.duration),
                  style: TextStyle(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onOpenApp(entry);
                    },
                    child: const Text('View app history'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UsageRingPainter extends CustomPainter {
  final List<AppUsageAppEntry> entries;
  final int total;
  final List<Color> colors;
  final Color trackColor;
  final double strokeWidth;

  const _UsageRingPainter({
    required this.entries,
    required this.total,
    required this.colors,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, track);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      final sweep = entries[index].duration.inMilliseconds /
          total *
          math.pi *
          2;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _UsageRingPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.total != total ||
        oldDelegate.trackColor != trackColor;
  }
}

class _RingTrend extends StatelessWidget {
  final double? value;

  const _RingTrend({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text(
        '—',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final increased = value! > 0;
    final decreased = value! < 0;
    final color = increased
        ? AppTheme.danger
        : decreased
            ? AppTheme.success
            : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = increased
        ? Icons.arrow_upward_rounded
        : decreased
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 2),
        Text(
          '${value!.abs().round()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w300,
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
  final FocusAnalysisResult? analysis;

  const _FocusInterruptionCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final value = analysis;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: value == null
          ? Row(
              children: [
                Icon(
                  Icons.do_not_disturb_on_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Finish a focus session to see interruption details.',
                    style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _MiniValue(
                  value: '${value.interruptionCount}',
                  label: 'interruptions',
                ),
                const SizedBox(width: 20),
                _MiniValue(
                  value: _duration(value.distractedDuration),
                  label: 'distracted',
                ),
                const SizedBox(width: 20),
                _MiniValue(
                  value: '${value.focusQuality.round()}%',
                  label: 'focus quality',
                ),
              ],
            ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  final String value;
  final String label;

  const _MiniValue({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageAccessCard extends StatelessWidget {
  final bool supported;
  final VoidCallback? onTap;

  const _UsageAccessCard({
    required this.supported,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                supported
                    ? Icons.shield_outlined
                    : Icons.desktop_windows_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  supported
                      ? 'Allow app usage access to see screen-time details.'
                      : 'Android app usage is not available on this device.',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

FocusAnalysisResult? _latestAnalysis(
  FocusProvider focus,
  UsageProvider usage,
) {
  final live = usage.focusAnalysisResult;
  if (live != null) return live;
  for (final session in focus.sessionHistory) {
    final saved = usage.storedFocusAnalyses[session.id];
    if (saved != null) return saved;
  }
  return null;
}

List<Color> _ringColors(BuildContext context) => [
      Theme.of(context).colorScheme.primary,
      AppTheme.lavender,
      AppTheme.mist,
      AppTheme.warning,
      AppTheme.success,
      AppTheme.danger,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
    ];

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${value.inMinutes}m';
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/daily_usage_summary.dart';
import '../../models/focus_analysis_result.dart';
import '../../models/usage_access_status.dart';
import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final summary = usageProvider.todaySummary;
    final analysis = usageProvider.focusAnalysisResult;
    final focusedToday =
        focusProvider.focusedDurationForDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Digital wellbeing',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: usageProvider.hasUsageAccess &&
                    !usageProvider.isRefreshing
                ? () => usageProvider.refreshUsage(force: true)
                : null,
            icon: usageProvider.isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            usageProvider.refreshPermissionAndUsage(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
          children: [
            if (!usageProvider.hasUsageAccess) ...[
              _PermissionBanner(
                status: usageProvider.accessStatus,
                onTap: () => context.push('/wellbeing/permission'),
              ),
              const SizedBox(height: 18),
            ],
            _WellbeingHero(
              summary: summary,
              comparisonPercent: usageProvider.todayVsYesterdayPercent,
            ),
            const SizedBox(height: 18),
            _MetricsGrid(
              usage: summary?.totalUsage,
              focused: focusedToday,
              distraction: analysis?.distractedDuration,
              quality: analysis?.focusQuality,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Text(
                  'App activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (summary != null)
                  TextButton(
                    onPressed: () =>
                        context.push('/wellbeing/app-usage'),
                    child: const Text('Details'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (summary == null)
              _NoUsageState(
                accessGranted: usageProvider.hasUsageAccess,
                onTap: usageProvider.hasUsageAccess
                    ? () => usageProvider.refreshUsage(force: true)
                    : () => context.push('/wellbeing/permission'),
              )
            else
              _AppDistribution(summary: summary),
            const SizedBox(height: 30),
            Text(
              'Focus interruptions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _InterruptionPanel(
              analysis: analysis,
              unavailableReason:
                  usageProvider.analysisUnavailableReason,
              hasUsageAccess: usageProvider.hasUsageAccess,
              onTap: analysis != null
                  ? () => context
                      .push('/wellbeing/focus-interruptions')
                  : usageProvider.hasUsageAccess
                      ? () => context.push('/focus/setup')
                      : () =>
                          context.push('/wellbeing/permission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellbeingHero extends StatelessWidget {
  final DailyUsageSummary? summary;
  final double? comparisonPercent;

  const _WellbeingHero({
    required this.summary,
    required this.comparisonPercent,
  });

  @override
  Widget build(BuildContext context) {
    final total = summary?.totalUsage;
    final entries = summary == null
        ? <MapEntry<String, Duration>>[]
        : (summary!.appUsage.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)));

    final top = entries.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 245,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 208,
                  height: 208,
                  child: CustomPaint(
                    painter: _UsageRingPainter(
                      shares: _sharesFor(top),
                      trackColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      colors: _ringColors(context),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TODAY',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      total == null ? '—' : _formatDuration(total),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _comparisonLabel(comparisonPercent),
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: List.generate(top.length, (index) {
                return _LegendItem(
                  color: _ringColors(context)[
                      index % _ringColors(context).length],
                  label: _cleanAppName(top[index].key),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  static List<double> _sharesFor(
    List<MapEntry<String, Duration>> entries,
  ) {
    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value.inMilliseconds,
    );

    if (total <= 0) {
      return const [];
    }

    return entries
        .map((entry) => entry.value.inMilliseconds / total)
        .toList();
  }

  static List<Color> _ringColors(BuildContext context) {
    return [
      Theme.of(context).colorScheme.primary,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.danger,
      const Color(0xFF9C6ADE),
      const Color(0xFF22A6B3),
    ];
  }
}

class _UsageRingPainter extends CustomPainter {
  final List<double> shares;
  final Color trackColor;
  final List<Color> colors;

  const _UsageRingPainter({
    required this.shares,
    required this.trackColor,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.085;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final arcRect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      track,
    );

    if (shares.isEmpty) {
      return;
    }

    var start = -math.pi / 2;

    for (var index = 0; index < shares.length; index++) {
      final sweep = math.pi * 2 * shares[index];
      if (sweep <= 0) {
        continue;
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[index % colors.length];

      canvas.drawArc(
        arcRect,
        start,
        math.max(0.0, sweep - 0.025).toDouble(),
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _UsageRingPainter oldDelegate) {
    return oldDelegate.shares != shares ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.colors != colors;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 95),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Duration? usage;
  final Duration focused;
  final Duration? distraction;
  final double? quality;

  const _MetricsGrid({
    required this.usage,
    required this.focused,
    required this.distraction,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _MetricTile(
          icon: Icons.smartphone_rounded,
          label: 'App usage',
          value: usage == null ? '—' : _formatDuration(usage!),
        ),
        _MetricTile(
          icon: Icons.timer_rounded,
          label: 'Focused',
          value: _formatDuration(focused),
        ),
        _MetricTile(
          icon: Icons.notifications_active_outlined,
          label: 'Distracted',
          value: distraction == null
              ? '—'
              : _formatDuration(distraction!),
        ),
        _MetricTile(
          icon: Icons.track_changes_rounded,
          label: 'Focus quality',
          value: quality == null
              ? '—'
              : '${(quality! * 100).clamp(0, 100).round()}%',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _AppDistribution extends StatelessWidget {
  final DailyUsageSummary summary;

  const _AppDistribution({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final entries = summary.appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value.inMilliseconds,
    );

    if (entries.isEmpty || total <= 0) {
      return const _NoUsageState(
        accessGranted: true,
        onTap: null,
      );
    }

    final visible = entries.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: List.generate(visible.length, (index) {
          final entry = visible[index];
          final share = entry.value.inMilliseconds / total;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == visible.length - 1 ? 0 : 18,
            ),
            child: _AppUsageRow(
              appName: _cleanAppName(entry.key),
              duration: entry.value,
              share: share,
            ),
          );
        }),
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  final String appName;
  final Duration duration;
  final double share;

  const _AppUsageRow({
    required this.appName,
    required this.duration,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                appName.isEmpty ? '?' : appName[0].toUpperCase(),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${(share * 100).round()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(duration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _InterruptionPanel extends StatelessWidget {
  final FocusAnalysisResult? analysis;
  final String? unavailableReason;
  final bool hasUsageAccess;
  final VoidCallback onTap;

  const _InterruptionPanel({
    required this.analysis,
    required this.unavailableReason,
    required this.hasUsageAccess,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final result = analysis;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: result == null
              ? Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.do_not_disturb_on_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        unavailableReason ??
                            (hasUsageAccess
                                ? 'Finish a focus session to measure real interruptions.'
                                : 'Connect Usage Access to measure interruptions.'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InlineMetric(
                            value: _formatDuration(
                              result.distractedDuration,
                            ),
                            label: 'distracted',
                          ),
                        ),
                        Expanded(
                          child: _InlineMetric(
                            value: '${result.interruptionCount}',
                            label: 'interruptions',
                          ),
                        ),
                        Expanded(
                          child: _InlineMetric(
                            value: result.topInterrupterApp == null
                                ? '—'
                                : _cleanAppName(
                                    result.topInterrupterApp!,
                                  ),
                            label: 'top app',
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String value;
  final String label;

  const _InlineMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final UsageAccessStatus status;
  final VoidCallback onTap;

  const _PermissionBanner({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status == UsageAccessStatus.unsupported
                      ? 'Real app usage is available on Android.'
                      : 'Allow Usage Access to measure real app activity.',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoUsageState extends StatelessWidget {
  final bool accessGranted;
  final VoidCallback? onTap;

  const _NoUsageState({
    required this.accessGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            accessGranted
                ? 'No measured usage yet'
                : 'Connect app usage',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            accessGranted
                ? 'Refresh after using a few apps to see real Android usage here.'
                : 'Focused needs Android Usage Access to build your real digital-wellbeing view.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTap,
              child: Text(
                accessGranted ? 'Refresh' : 'Connect',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _comparisonLabel(double? value) {
  if (value == null) {
    return 'No comparison yet';
  }

  if (value > 0) {
    return '↑ ${value.abs().round()}% vs yesterday';
  }

  if (value < 0) {
    return '↓ ${value.abs().round()}% vs yesterday';
  }

  return 'Same as yesterday';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  return '${duration.inMinutes}m';
}

String _cleanAppName(String value) {
  if (!value.contains('.')) {
    return value;
  }

  final parts = value
      .split('.')
      .where((part) => part.trim().isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return value;
  }

  final last = parts.last;
  return last.isEmpty
      ? value
      : '${last[0].toUpperCase()}${last.substring(1)}';
}

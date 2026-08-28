import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_usage_summary.dart';
import '../../models/hourly_usage_summary.dart';
import '../../models/usage_access_status.dart';
import '../../providers/usage_provider.dart';

class AppUsageDetailsScreen extends StatelessWidget {
  const AppUsageDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsageProvider>();
    final summary = provider.todaySummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App activity',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isRefreshing
                ? null
                : () => provider.refreshPermissionAndUsage(force: true),
            icon: provider.isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: summary == null
          ? _UnavailableBody(
              status: provider.accessStatus,
              error: provider.lastError,
              onAction: provider.hasUsageAccess
                  ? () => provider.refreshPermissionAndUsage(force: true)
                  : provider.requestUsageAccess,
            )
          : RefreshIndicator(
              onRefresh: () =>
                  provider.refreshPermissionAndUsage(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                children: [
                  _UsageTotal(
                    summary: summary,
                    comparison: provider.todayVsYesterdayPercent,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Hourly activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Foreground app usage reported by Android today.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  _HourlyChart(
                    hourlyUsage: summary.hourlyUsage,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Apps',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _AppActivityList(
                    summary: summary,
                    provider: provider,
                  ),
                ],
              ),
            ),
    );
  }
}

class _UsageTotal extends StatelessWidget {
  final DailyUsageSummary summary;
  final double? comparison;

  const _UsageTotal({
    required this.summary,
    required this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          _formatDuration(summary.totalUsage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Today',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _comparisonText(comparison),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final List<HourlyUsageSummary> hourlyUsage;

  const _HourlyChart({
    required this.hourlyUsage,
  });

  @override
  Widget build(BuildContext context) {
    final visible = hourlyUsage
        .where((item) => item.hourStart.hour % 2 == 0)
        .toList();

    final maxMinutes = visible.fold<int>(
      1,
      (maxValue, item) =>
          item.totalUsage.inMinutes > maxValue
              ? item.totalUsage.inMinutes
              : maxValue,
    );

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: visible.map((item) {
          final minutes = item.totalUsage.inMinutes;
          final ratio = minutes / maxMinutes;

          return Expanded(
            child: Tooltip(
              message:
                  '${_hourLabel(item.hourStart.hour)} • ${minutes}m',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.03, 1.0),
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            color: minutes == 0
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _shortHour(item.hourStart.hour),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AppActivityList extends StatelessWidget {
  final DailyUsageSummary summary;
  final UsageProvider provider;

  const _AppActivityList({
    required this.summary,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final entries = summary.appUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('No app activity measured today.'),
        ),
      );
    }

    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value.inMilliseconds,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final share = total <= 0
              ? 0.0
              : entry.value.inMilliseconds / total;
          final change = provider.getAppChangePercent(entry.key);

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    _cleanAppName(entry.key)[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  _cleanAppName(entry.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${(share * 100).round()}% of measured app usage'
                  '${_changeSuffix(change)}',
                ),
                trailing: Text(
                  _formatDuration(entry.value),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  indent: 72,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _UnavailableBody extends StatelessWidget {
  final UsageAccessStatus status;
  final String? error;
  final Future<void> Function() onAction;

  const _UnavailableBody({
    required this.status,
    required this.error,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final unsupported = status == UsageAccessStatus.unsupported;
    final checking = status == UsageAccessStatus.checking;

    if (checking) {
      return const Center(child: CircularProgressIndicator());
    }

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
                  ? 'Android app activity is not available here'
                  : 'App activity needs Usage Access',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              unsupported
                  ? 'Windows will use a separate foreground-app collector later.'
                  : 'Focused uses Android UsageStats to build this view from real foreground-app activity.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (!unsupported) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => onAction(),
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _comparisonText(double? value) {
  if (value == null) {
    return 'No yesterday comparison yet';
  }

  if (value > 0) {
    return '${value.abs().round()}% more than yesterday';
  }

  if (value < 0) {
    return '${value.abs().round()}% less than yesterday';
  }

  return 'Same as yesterday';
}

String _changeSuffix(double? value) {
  if (value == null || value == 0) {
    return '';
  }

  final direction = value > 0 ? ' • ↑ ' : ' • ↓ ';
  return '$direction${value.abs().round()}% vs yesterday';
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
    return value.isEmpty ? 'Unknown app' : value;
  }

  final parts =
      value.split('.').where((part) => part.isNotEmpty).toList();

  if (parts.isEmpty) {
    return 'Unknown app';
  }

  final last = parts.last;
  if (last.isEmpty) {
    return 'Unknown app';
  }

  return '${last[0].toUpperCase()}${last.substring(1)}';
}

String _shortHour(int hour) {
  if (hour == 0) {
    return '12a';
  }
  if (hour == 12) {
    return '12p';
  }
  if (hour < 12) {
    return '${hour}a';
  }
  return '${hour - 12}p';
}

String _hourLabel(int hour) {
  if (hour == 0) {
    return '12 AM';
  }
  if (hour == 12) {
    return '12 PM';
  }
  if (hour < 12) {
    return '$hour AM';
  }
  return '${hour - 12} PM';
}

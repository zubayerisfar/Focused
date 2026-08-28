import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_usage_summary.dart';
import '../../models/hourly_usage_summary.dart';
import '../../models/usage_access_status.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';

class AppUsageDetailsScreen extends StatefulWidget {
  const AppUsageDetailsScreen({super.key});

  @override
  State<AppUsageDetailsScreen> createState() => _AppUsageDetailsScreenState();
}

class _AppUsageDetailsScreenState extends State<AppUsageDetailsScreen> {
  int _selectedPeriod = 0;

  final List<String> _periods = const ['Day', 'Week', 'Month'];

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();

    final todaySummary = usageProvider.todaySummary;
    final yesterdaySummary = usageProvider.yesterdaySummary;

    if (todaySummary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Usage')),
        body: _UsageUnavailableBody(
          status: usageProvider.accessStatus,
          refreshing: usageProvider.isRefreshing,
          error: usageProvider.lastError,
          onGrant: usageProvider.requestUsageAccess,
          onRefresh: () => usageProvider.refreshPermissionAndUsage(force: true),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage'),
        actions: [
          IconButton(
            tooltip: 'Refresh real usage',
            onPressed: usageProvider.isRefreshing
                ? null
                : () => usageProvider.refreshPermissionAndUsage(force: true),
            icon: usageProvider.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => usageProvider.refreshPermissionAndUsage(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SegmentedButton<int>(
            segments: List.generate(
              _periods.length,
              (index) => ButtonSegment<int>(
                value: index,
                label: Text(_periods[index]),
              ),
            ),
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedPeriod = selection.first;
              });
            },
          ),
          if (_selectedPeriod == 0) ...[
            const SizedBox(height: 22),

            _TotalUsageCard(
              totalUsage: todaySummary.totalUsage,
              previousUsage: yesterdaySummary?.totalUsage,
            ),

            const SizedBox(height: 24),

            Text(
              'Hourly usage',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 6),

            Text(
              'See when Android reported the most foreground-app activity today.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 12),

            _HourlyUsageChart(hourlyUsage: todaySummary.hourlyUsage),

            const SizedBox(height: 26),

            Text(
              'Most used apps',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            _AppListCard(
              today: todaySummary,
              yesterday: yesterdaySummary,
              usageProvider: usageProvider,
            ),

            const SizedBox(height: 26),

            Text(
              'Comparison',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            _ComparisonCard(
              todayPercent: usageProvider.todayVsYesterdayPercent,
            ),
          ] else ...[
            const SizedBox(height: 24),

            _HistoryRequiredCard(period: _periods[_selectedPeriod]),
          ],
        ],
        ),
      ),
    );
  }
}

class _UsageUnavailableBody extends StatelessWidget {
  final UsageAccessStatus status;
  final bool refreshing;
  final String? error;
  final Future<void> Function() onGrant;
  final Future<void> Function() onRefresh;

  const _UsageUnavailableBody({
    required this.status,
    required this.refreshing,
    required this.error,
    required this.onGrant,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (refreshing || status == UsageAccessStatus.checking) {
      return const Center(child: CircularProgressIndicator());
    }

    final unsupported = status == UsageAccessStatus.unsupported;
    final granted = status == UsageAccessStatus.granted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unsupported ? Icons.desktop_windows_outlined : Icons.shield_outlined,
              size: 54,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
              unsupported
                  ? 'Android UsageStats is not available here'
                  : granted
                      ? 'No usage snapshot yet'
                      : 'Usage Access is required',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              unsupported
                  ? 'Real app-usage collection is currently implemented for Android. Windows will use a separate foreground-window collector later.'
                  : granted
                      ? 'Refresh to query real foreground-app events from Android.'
                      : 'Grant Focused Usage Access in Android settings to read real foreground-app history.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            if (!unsupported)
              FilledButton.icon(
                onPressed: () async {
                  if (granted) {
                    await onRefresh();
                  } else {
                    await onGrant();
                  }
                },
                icon: Icon(granted ? Icons.refresh_rounded : Icons.open_in_new_rounded),
                label: Text(granted ? 'Refresh usage' : 'Grant Usage Access'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalUsageCard extends StatelessWidget {
  final Duration totalUsage;
  final Duration? previousUsage;

  const _TotalUsageCard({
    required this.totalUsage,
    required this.previousUsage,
  });

  @override
  Widget build(BuildContext context) {
    String comparisonText = 'No comparison available';
    String badgeText = '—';

    if (previousUsage != null) {
      final differenceSeconds = totalUsage.inSeconds - previousUsage!.inSeconds;

      if (previousUsage!.inSeconds > 0) {
        final percentage = (differenceSeconds / previousUsage!.inSeconds) * 100;

        if (differenceSeconds > 0) {
          badgeText = '↑ ${percentage.abs().round()}%';

          comparisonText =
              '${_formatDuration(Duration(seconds: differenceSeconds))} more than yesterday';
        } else if (differenceSeconds < 0) {
          badgeText = '↓ ${percentage.abs().round()}%';

          comparisonText =
              '${_formatDuration(Duration(seconds: differenceSeconds.abs()))} less than yesterday';
        } else {
          badgeText = '0%';
          comparisonText = 'Same as yesterday';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            _formatDuration(totalUsage),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 2),

          Text(
            'Measured app usage today',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            comparisonText,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HourlyUsageChart extends StatelessWidget {
  final List<HourlyUsageSummary> hourlyUsage;

  const _HourlyUsageChart({required this.hourlyUsage});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: hourlyUsage.map((summary) {
            final minutes = summary.totalUsage.inMinutes;

            final usageRatio = (minutes / 60).clamp(0.0, 1.0).toDouble();

            final showLabel = summary.hourStart.hour % 3 == 0;

            return SizedBox(
              width: 38,
              child: Tooltip(
                message: '${_hourText(summary.hourStart.hour)} • ${minutes}m',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 18,
                          height: minutes == 0 ? 2 : 145 * usageRatio,
                          decoration: BoxDecoration(
                            color: minutes == 0
                                ? AppTheme.primaryBlue.withOpacity(0.08)
                                : AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      showLabel ? _shortHourText(summary.hourStart.hour) : '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AppListCard extends StatelessWidget {
  final DailyUsageSummary today;
  final DailyUsageSummary? yesterday;
  final UsageProvider usageProvider;

  const _AppListCard({
    required this.today,
    required this.yesterday,
    required this.usageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final entries = today.appUsage.entries.toList()
      ..sort((a, b) => b.value.inSeconds.compareTo(a.value.inSeconds));

    if (entries.isEmpty) {
      return const Center(child: Text('No app usage today'));
    }

    final totalSeconds = today.totalUsage.inSeconds;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];

          final percentage = totalSeconds == 0
              ? 0.0
              : entry.value.inSeconds / totalSeconds;

          final change = usageProvider.getAppChangePercent(entry.key);

          String changeText;

          if (change == null) {
            changeText = 'New';
          } else if (change > 0) {
            changeText = '↑ ${change.abs().round()}%';
          } else if (change < 0) {
            changeText = '↓ ${change.abs().round()}%';
          } else {
            changeText = '0%';
          }

          return Column(
            children: [
              _AppUsageItem(
                icon: _iconForApp(entry.key),
                name: entry.key,
                duration: _formatDuration(entry.value),
                percent: '${(percentage * 100).round()}%',
                change: changeText,
                changeColor: Theme.of(context).colorScheme.onSurfaceVariant,
                progress: percentage.clamp(0.0, 1.0),
              ),

              if (index != entries.length - 1) const SizedBox(height: 20),
            ],
          );
        }),
      ),
    );
  }
}

class _AppUsageItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String duration;
  final String percent;
  final String change;
  final Color changeColor;
  final double progress;

  const _AppUsageItem({
    required this.icon,
    required this.name,
    required this.duration,
    required this.percent,
    required this.change,
    required this.changeColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    duration,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.52),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: AppTheme.primaryBlue,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final double? todayPercent;

  const _ComparisonCard({required this.todayPercent});

  @override
  Widget build(BuildContext context) {
    String todayValue;

    if (todayPercent == null) {
      todayValue = 'No history';
    } else if (todayPercent! > 0) {
      todayValue = '+${todayPercent!.abs().round()}%';
    } else if (todayPercent! < 0) {
      todayValue = '-${todayPercent!.abs().round()}%';
    } else {
      todayValue = '0%';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _ComparisonRow(label: 'Today vs yesterday', value: todayValue),

          const Divider(height: 28),

          const _ComparisonRow(
            label: 'This week vs last week',
            value: 'Waiting for history',
          ),

          const Divider(height: 28),

          const _ComparisonRow(
            label: 'This month vs last month',
            value: 'Waiting for history',
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value;

  const _ComparisonRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _HistoryRequiredCard extends StatelessWidget {
  final String period;

  const _HistoryRequiredCard({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 42,
            color: AppTheme.primaryBlue,
          ),

          const SizedBox(height: 14),

          Text(
            '$period analytics needs usage history',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 8),

          Text(
            'Focused now saves daily usage snapshots locally. Weekly, monthly, and yearly aggregation will be added after this real-data pipeline is validated on devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;

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

String _hourText(int hour) {
  if (hour == 0) {
    return '12:00 AM';
  }

  if (hour < 12) {
    return '$hour:00 AM';
  }

  if (hour == 12) {
    return '12:00 PM';
  }

  return '${hour - 12}:00 PM';
}

String _shortHourText(int hour) {
  if (hour == 0) {
    return '12a';
  }

  if (hour < 12) {
    return '${hour}a';
  }

  if (hour == 12) {
    return '12p';
  }

  return '${hour - 12}p';
}

IconData _iconForApp(String appName) {
  switch (appName.toLowerCase()) {
    case 'instagram':
      return Icons.photo_camera_outlined;

    case 'youtube':
      return Icons.play_circle_outline_rounded;

    case 'chrome':
      return Icons.public_rounded;

    case 'whatsapp':
      return Icons.chat_bubble_outline_rounded;

    case 'vs code':
      return Icons.code_rounded;

    default:
      return Icons.apps_rounded;
  }
}

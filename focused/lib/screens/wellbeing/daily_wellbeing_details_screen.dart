import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/daily_usage_metrics.dart';
import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_banner_ad_widget.dart';
import '../../widgets/app_icon.dart';

class DailyWellbeingDetailsScreen extends StatefulWidget {
  const DailyWellbeingDetailsScreen({super.key, required this.date});
  final DateTime date;

  @override
  State<DailyWellbeingDetailsScreen> createState() =>
      _DailyWellbeingDetailsScreenState();
}

class _DailyWellbeingDetailsScreenState
    extends State<DailyWellbeingDetailsScreen> {
  late Future<List<DailyUsageMetrics>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<UsageProvider>().loadDailyUsageHistory(
      days: 1,
      endDay: widget.date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final focus = context.watch<FocusProvider>();
    final focused = focus.focusedDurationForDate(widget.date);
    final distracted = usage.focusDistractedDurationForDate(widget.date);
    final interruptionCount = usage.focusInterruptionCountForDate(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(widget.date)),
      ),
      body: FutureBuilder<List<DailyUsageMetrics>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final day = snapshot.data?.isNotEmpty == true
              ? snapshot.data!.first
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            children: [
              _DayMetricGrid(
                values: [
                  _DayMetric(
                    label: 'Screen time',
                    value: day == null || !day.measured
                        ? '—'
                        : _duration(day.totalUsage),
                    icon: FontAwesomeIcons.mobileScreen,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _DayMetric(
                    label: 'Focused',
                    value: _duration(focused),
                    icon: FontAwesomeIcons.bullseye,
                    color: AppTheme.success,
                  ),
                  _DayMetric(
                    label: 'Distracted',
                    value: _duration(distracted),
                    icon: FontAwesomeIcons.triangleExclamation,
                    color: AppTheme.danger,
                  ),
                  _DayMetric(
                    label: 'Interruptions',
                    value: '$interruptionCount',
                    icon: FontAwesomeIcons.bell,
                    color: AppTheme.warning,
                  ),
                ],
              ),
              if (day == null || !day.measured) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'No local screen-time measurement exists for this date on this device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Top apps',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (day == null || day.topApps.isEmpty)
                const Text('No app-usage details were measured for this day.')
              else
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: List.generate(
                      day.topApps.length > 6 ? 6 : day.topApps.length,
                      (index) {
                        final app = day.topApps[index];
                        return ListTile(
                          leading: AppIcon(
                            iconBytes: app.iconBytes,
                            appName: app.appName,
                            size: 36,
                            borderRadius: 10,
                          ),
                          title: Text(
                            app.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _duration(app.duration),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const AppBannerAdWidget(),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    );
  }
}

class _DayMetric {
  const _DayMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final FaIconData icon;
  final Color color;
}

class _DayMetricGrid extends StatelessWidget {
  const _DayMetricGrid({required this.values});
  final List<_DayMetric> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FaIcon(item.icon, color: item.color, size: 18),
                        const SizedBox(height: 15),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
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

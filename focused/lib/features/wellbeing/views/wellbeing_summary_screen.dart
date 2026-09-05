import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_category.dart';
import '../../focus/models/focus_analysis_result.dart';
import '../../focus/providers/focus_provider.dart';
import '../providers/usage_provider.dart';
import '../../../core/theme/app_theme.dart';

class WellbeingSummaryScreen extends StatelessWidget {
  const WellbeingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final focus = context.watch<FocusProvider>();
    final now = DateTime.now();
    final latestAnalysis = _latestAnalysis(focus, usage);

    return Scaffold(
      appBar: AppBar(title: const Text('Overall summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => context.push('/wellbeing/analytics'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.calendar_view_week_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '7-day summary',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'See how this week compares with the last.',
                            style: TextStyle(fontWeight: FontWeight.w300),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Your day in simple numbers',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick view of screen time, focus, and distractions.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 22),
          _MetricGrid(
            values: [
              _SummaryMetric(
                label: 'Screen time',
                value: usage.todaySummary == null
                    ? '—'
                    : _duration(usage.todaySummary!.totalUsage),
                icon: Icons.smartphone_rounded,
                color: AppTheme.mist,
              ),
              _SummaryMetric(
                label: 'Focused',
                value: _duration(focus.focusedDurationForDate(now)),
                icon: Icons.center_focus_strong_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              _SummaryMetric(
                label: 'Productive apps',
                value: usage.todaySummary == null
                    ? '—'
                    : _duration(
                        usage.usageForCategoryToday(AppCategory.productive),
                      ),
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.success,
              ),
              _SummaryMetric(
                label: 'Distracting apps',
                value: usage.todaySummary == null
                    ? '—'
                    : _duration(
                        usage.usageForCategoryToday(AppCategory.distracting),
                      ),
                icon: Icons.warning_amber_rounded,
                color: AppTheme.danger,
              ),
              _SummaryMetric(
                label: 'Focus quality',
                value: latestAnalysis == null
                    ? '—'
                    : '${latestAnalysis.focusQuality.round()}%',
                icon: Icons.bolt_rounded,
                color: AppTheme.lavender,
              ),
              _SummaryMetric(
                label: 'Interruptions',
                value: latestAnalysis == null
                    ? '—'
                    : '${latestAnalysis.interruptionCount}',
                icon: Icons.notifications_active_outlined,
                color: AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),
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

class _MetricGrid extends StatelessWidget {
  final List<_SummaryMetric> values;

  const _MetricGrid({required this.values});

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
                    constraints: const BoxConstraints(minHeight: 124),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: item.color, size: 22),
                        const SizedBox(height: 18),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 22,
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
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

String _duration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return minutes == 0
        ? '${duration.inHours}h'
        : '${duration.inHours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

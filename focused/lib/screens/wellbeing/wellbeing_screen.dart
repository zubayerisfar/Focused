import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../../providers/usage_provider.dart';

import '../../theme/app_theme.dart';

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();

    final todaySummary = usageProvider.todaySummary;

    final screenTimeText = todaySummary == null
        ? '0m'
        : _formatDuration(todaySummary.totalUsage);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _PermissionBanner(onTap: () => context.push('/wellbeing/permission')),
        const SizedBox(height: 20),
        Text(
          'Today',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.phone_android_rounded,
                value: screenTimeText,
                label: 'Screen time',
                helper: 'Today',
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.timer_rounded,
                value: '2h 40m',
                label: 'Focused time',
                helper: '3 sessions',
                color: Color(0xFF34B27B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.notifications_active_outlined,
                value: '36m',
                label: 'Distraction',
                helper: '↓ 8% vs yesterday',
                color: Color(0xFFFF8A65),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.track_changes_rounded,
                value: '86%',
                label: 'Focus quality',
                helper: 'Good',
                color: Color(0xFF8E67D4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'App usage',
          actionText: 'View details',
          onTap: () => context.push('/wellbeing/app-usage'),
        ),
        const SizedBox(height: 12),
        _AppUsagePreview(onTap: () => context.push('/wellbeing/app-usage')),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Focus interruptions',
          actionText: 'View details',
          onTap: () => context.push('/wellbeing/focus-interruptions'),
        ),
        const SizedBox(height: 12),
        _InterruptionPreview(
          onTap: () => context.push('/wellbeing/focus-interruptions'),
        ),
        const SizedBox(height: 28),
        Text(
          'This week',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const _WeeklySummaryCard(),
        const SizedBox(height: 28),
        Text(
          'Insight',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const _InsightCard(),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PermissionBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usage access is not connected',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grant Android Usage Access to measure app time and focus interruptions.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.60),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionText)),
      ],
    );
  }
}

class _AppUsagePreview extends StatelessWidget {
  final VoidCallback onTap;

  const _AppUsagePreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            children: [
              _AppUsageRow(
                icon: Icons.photo_camera_outlined,
                appName: 'Instagram',
                duration: '1h 28m',
                change: '↑ 21%',
                changeColor: Color(0xFFFF6B5E),
                progress: 0.82,
              ),
              SizedBox(height: 18),
              _AppUsageRow(
                icon: Icons.play_circle_outline_rounded,
                appName: 'YouTube',
                duration: '58m',
                change: '↓ 14%',
                changeColor: Color(0xFF34B27B),
                progress: 0.58,
              ),
              SizedBox(height: 18),
              _AppUsageRow(
                icon: Icons.public_rounded,
                appName: 'Chrome',
                duration: '47m',
                change: '↑ 5%',
                changeColor: Color(0xFFFF8A65),
                progress: 0.46,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  final IconData icon;
  final String appName;
  final String duration;
  final String change;
  final Color changeColor;
  final double progress;

  const _AppUsageRow({
    required this.icon,
    required this.appName,
    required this.duration,
    required this.change,
    required this.changeColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    duration,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      change,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: changeColor,
                      ),
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

class _InterruptionPreview extends StatelessWidget {
  final VoidCallback onTap;

  const _InterruptionPreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A65).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF8A65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Study Flutter',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text('2:00 PM – 3:30 PM'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(
                    child: _MiniMetric(label: 'Planned', value: '90m'),
                  ),
                  Expanded(
                    child: _MiniMetric(label: 'Effective', value: '77m'),
                  ),
                  Expanded(
                    child: _MiniMetric(label: 'Distracted', value: '13m'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 19,
                    color: Color(0xFFFF8A65),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '3 interruptions',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  Text(
                    '86% quality',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF34B27B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.52),
          ),
        ),
      ],
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: _WeeklyMetric(
                  label: 'Screen time',
                  value: '27h 12m',
                  change: '↓ 6%',
                  color: Color(0xFF34B27B),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WeeklyMetric(
                  label: 'Distraction',
                  value: '3h 08m',
                  change: '↓ 18%',
                  color: Color(0xFF34B27B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _DayBar(day: 'M', value: 0.72),
              _DayBar(day: 'T', value: 0.55),
              _DayBar(day: 'W', value: 0.82),
              _DayBar(day: 'T', value: 0.64),
              _DayBar(day: 'F', value: 0.48),
              _DayBar(day: 'S', value: 0.38),
              _DayBar(day: 'S', value: 0.58),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyMetric extends StatelessWidget {
  final String label;
  final String value;
  final String change;
  final Color color;

  const _WeeklyMetric({
    required this.label,
    required this.value,
    required this.change,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$change vs last week',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final double value;

  const _DayBar({required this.day, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF34B27B).withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF34B27B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your distraction time is down 18% compared with last week. '
              'Instagram still causes the most focus interruptions.',
              style: TextStyle(
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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

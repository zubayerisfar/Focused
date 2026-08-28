import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final now = DateTime.now();

    final todaySummary = usageProvider.todaySummary;
    final focusedToday = focusProvider.focusedDurationForDate(now);
    final sessionsToday = focusProvider.sessionCountForDate(now);
    final analysis = usageProvider.focusAnalysisResult;

    final screenTimeText = todaySummary == null
        ? '—'
        : _formatDuration(todaySummary.totalUsage);
    final distractionText = analysis == null
        ? '—'
        : _formatDuration(analysis.distractedDuration);
    final qualityText = analysis == null
        ? '—'
        : '${(analysis.focusQuality * 100).clamp(0, 100).round()}%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _PermissionBanner(
          onTap: () => context.push('/wellbeing/permission'),
        ),
        const SizedBox(height: 20),
        Text(
          'Today',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.phone_android_rounded,
                value: screenTimeText,
                label: 'Screen time',
                helper: todaySummary == null
                    ? 'Usage Access needed'
                    : 'Measured today',
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.timer_rounded,
                value: _formatDuration(focusedToday),
                label: 'Focused time',
                helper: '$sessionsToday ${sessionsToday == 1 ? 'session' : 'sessions'}',
                color: const Color(0xFF34B27B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.notifications_active_outlined,
                value: distractionText,
                label: 'Distraction',
                helper: analysis == null
                    ? 'Usage data needed'
                    : '${analysis.interruptionCount} interruptions',
                color: const Color(0xFFFF8A65),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.track_changes_rounded,
                value: qualityText,
                label: 'Focus quality',
                helper: analysis == null
                    ? 'Not calculated yet'
                    : 'Effective / planned',
                color: const Color(0xFF8E67D4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'App usage',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        _UnavailableDataCard(
          icon: Icons.apps_rounded,
          title: 'Real app usage is not connected yet',
          body:
              'The next platform stage will read Android UsageStats instead of showing demo app data.',
          action: 'Set up usage access',
          onTap: () => context.push('/wellbeing/permission'),
        ),
        const SizedBox(height: 28),
        Text(
          'Focus interruptions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        _UnavailableDataCard(
          icon: Icons.warning_amber_rounded,
          title: 'Waiting for real app intervals',
          body:
              'Your stored focus intervals are ready. Interruption analysis will become real after Android app-usage collection is connected.',
          action: 'Learn about usage access',
          onTap: () => context.push('/wellbeing/permission'),
        ),
        const SizedBox(height: 28),
        Text(
          'Historical insights',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        const _FutureInsightsCard(),
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
                      'Focused does not show fabricated app-usage numbers while real UsageStats is unavailable.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.60),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.55),
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

class _UnavailableDataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  const _UnavailableDataCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.56),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onTap,
                  child: Text(action),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureInsightsCard extends StatelessWidget {
  const _FutureInsightsCard();

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
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF34B27B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Focus history is now persistent. Daily, weekly, monthly, and app-based insights will be generated only from real stored data.',
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
  if (duration.inSeconds <= 0) {
    return '0m';
  }

  if (duration.inSeconds < 60) {
    return '<1m';
  }

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

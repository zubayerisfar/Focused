import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
    final now = DateTime.now();

    final todaySummary = usageProvider.todaySummary;
    final focusedToday = focusProvider.focusedDurationForDate(now);
    final sessionsToday = focusProvider.sessionCountForDate(now);
    final analysis = usageProvider.focusAnalysisResult;

    final appUsageText = todaySummary == null
        ? '—'
        : _formatDuration(todaySummary.totalUsage);
    final distractionText = analysis == null
        ? '—'
        : _formatDuration(analysis.distractedDuration);
    final qualityText = analysis == null
        ? '—'
        : '${analysis.focusQuality.clamp(0.0, 100.0).round()}%';

    return RefreshIndicator(
      onRefresh: () => usageProvider.refreshPermissionAndUsage(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _PermissionBanner(
            status: usageProvider.accessStatus,
            refreshing: usageProvider.isRefreshing,
            lastUpdatedAt: usageProvider.lastUpdatedAt,
            onTap: () {
              if (usageProvider.hasUsageAccess) {
                context.push('/wellbeing/app-usage');
              } else {
                context.push('/wellbeing/permission');
              }
            },
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
                  value: appUsageText,
                  label: 'App usage',
                  helper: todaySummary == null
                      ? _usageHelper(usageProvider.accessStatus)
                      : 'Measured from Android',
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.timer_rounded,
                  value: _formatDuration(focusedToday),
                  label: 'Focused time',
                  helper:
                      '$sessionsToday ${sessionsToday == 1 ? 'session' : 'sessions'}',
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
                  label: 'Latest distraction',
                  helper: analysis == null
                      ? usageProvider.analysisUnavailableReason ??
                          'Complete a focus session'
                      : '${analysis.interruptionCount} interruptions',
                  color: const Color(0xFFFF8A65),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.track_changes_rounded,
                  value: qualityText,
                  label: 'Latest focus quality',
                  helper: analysis == null
                      ? 'Waiting for session analysis'
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
          if (todaySummary != null)
            _RealUsageCard(
              totalUsage: todaySummary.totalUsage,
              mostUsedApp: todaySummary.mostUsedApp,
              changePercent: usageProvider.todayVsYesterdayPercent,
              refreshing: usageProvider.isRefreshing,
              onTap: () => context.push('/wellbeing/app-usage'),
            )
          else
            _UnavailableDataCard(
              icon: Icons.apps_rounded,
              title: usageProvider.accessStatus == UsageAccessStatus.granted
                  ? 'Waiting for Android usage data'
                  : 'Connect Android Usage Access',
              body: usageProvider.accessStatus == UsageAccessStatus.granted
                  ? 'Pull down to refresh real foreground-app usage from this device.'
                  : 'Focused needs the Android Usage Access setting before it can read real app activity.',
              action: usageProvider.accessStatus == UsageAccessStatus.granted
                  ? 'Refresh usage'
                  : 'Set up usage access',
              onTap: usageProvider.accessStatus == UsageAccessStatus.granted
                  ? () => usageProvider.refreshUsage(force: true)
                  : () => context.push('/wellbeing/permission'),
            ),
          const SizedBox(height: 28),
          Text(
            'Focus interruptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (usageProvider.isAnalyzingFocus)
            const _AnalysisProgressCard()
          else if (analysis != null)
            _LatestFocusAnalysisCard(
              distraction: analysis.distractedDuration,
              interruptions: analysis.interruptionCount,
              topInterrupter: analysis.topInterrupterApp,
              quality: analysis.focusQuality,
              onTap: () => context.push('/wellbeing/focus-interruptions'),
            )
          else
            _UnavailableDataCard(
              icon: Icons.warning_amber_rounded,
              title: 'No real interruption result yet',
              body: usageProvider.analysisUnavailableReason ??
                  'Complete a focus session after Usage Access is granted. Focused will query the exact session window.',
              action: usageProvider.hasUsageAccess
                  ? 'Start a focus session'
                  : 'Set up usage access',
              onTap: usageProvider.hasUsageAccess
                  ? () => context.push('/focus/setup')
                  : () => context.push('/wellbeing/permission'),
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
      ),
    );
  }

  String _usageHelper(UsageAccessStatus status) {
    switch (status) {
      case UsageAccessStatus.granted:
        return 'Pull to refresh';
      case UsageAccessStatus.denied:
        return 'Usage Access needed';
      case UsageAccessStatus.unsupported:
        return 'Android only';
      case UsageAccessStatus.error:
        return 'Usage service error';
      case UsageAccessStatus.checking:
      case UsageAccessStatus.unknown:
        return 'Checking access';
    }
  }
}

class _PermissionBanner extends StatelessWidget {
  final UsageAccessStatus status;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final VoidCallback onTap;

  const _PermissionBanner({
    required this.status,
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == UsageAccessStatus.granted;
    final title = granted
        ? 'Android Usage Access connected'
        : status == UsageAccessStatus.unsupported
            ? 'Usage monitoring is Android only'
            : 'Connect Android Usage Access';

    final subtitle = refreshing
        ? 'Refreshing real app-usage intervals…'
        : granted
            ? lastUpdatedAt == null
                ? 'Access is granted. Tap to view real app usage.'
                : 'Last refreshed ${_formatClock(lastUpdatedAt!)} • tap for app usage.'
            : 'Focused will not fabricate usage numbers while access is unavailable.';

    final color = granted ? const Color(0xFF34B27B) : AppTheme.primaryBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  granted ? Icons.verified_user_outlined : Icons.shield_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

class _RealUsageCard extends StatelessWidget {
  final Duration totalUsage;
  final String? mostUsedApp;
  final double? changePercent;
  final bool refreshing;
  final VoidCallback onTap;

  const _RealUsageCard({
    required this.totalUsage,
    required this.mostUsedApp,
    required this.changePercent,
    required this.refreshing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String comparison;
    final change = changePercent;
    if (change == null) {
      comparison = 'No comparable yesterday baseline yet';
    } else if (change > 0) {
      comparison = '${change.abs().round()}% more than yesterday';
    } else if (change < 0) {
      comparison = '${change.abs().round()}% less than yesterday';
    } else {
      comparison = 'Same as yesterday';
    }

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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(totalUsage),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (refreshing) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mostUsedApp == null
                          ? 'No foreground apps measured yet'
                          : 'Most used: $mostUsedApp',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comparison,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.55),
                      ),
                    ),
                  ],
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

class _LatestFocusAnalysisCard extends StatelessWidget {
  final Duration distraction;
  final int interruptions;
  final String? topInterrupter;
  final double quality;
  final VoidCallback onTap;

  const _LatestFocusAnalysisCard({
    required this.distraction,
    required this.interruptions,
    required this.topInterrupter,
    required this.quality,
    required this.onTap,
  });

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
          child: Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                color: Color(0xFF8E67D4),
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${quality.clamp(0.0, 100.0).round()}% focus quality',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(distraction)} distracted • $interruptions ${interruptions == 1 ? 'episode' : 'episodes'}',
                    ),
                    if (topInterrupter != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Top interrupter: $topInterrupter',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.55),
                        ),
                      ),
                    ],
                  ],
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

class _AnalysisProgressCard extends StatelessWidget {
  const _AnalysisProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Reading real app activity for the focus-session window…',
              style: TextStyle(fontWeight: FontWeight.w700),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.58),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timeline_rounded, color: AppTheme.primaryBlue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Today and yesterday now use real Android data. Multi-week/month history and trend insights will be built after the real-data pipeline is validated on devices.',
              style: TextStyle(height: 1.4),
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

String _formatClock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

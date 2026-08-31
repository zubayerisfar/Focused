import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_analysis_result.dart';
import '../../models/focus_interruption.dart';
import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

class FocusInterruptionDetailsScreen extends StatelessWidget {
  const FocusInterruptionDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final focusProvider = context.watch<FocusProvider>();
    final result = _latestSavedAnalysis(focusProvider, usageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Focus analysis',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: result == null
          ? _NoFocusAnalysis(
              onRefresh: () async {
                await usageProvider.refreshPermissionAndUsage(force: true);
              },
            )
          : _FocusAnalysisBody(result: result),
    );
  }
}

FocusAnalysisResult? _latestSavedAnalysis(
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

class _NoFocusAnalysis extends StatelessWidget {
  const _NoFocusAnalysis({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.center_focus_strong_rounded, size: 46),
            const SizedBox(height: 16),
            Text(
              'No focus analysis yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a focus session first. Focused will then show interruptions, effective focus and the top interrupter here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusAnalysisBody extends StatelessWidget {
  final FocusAnalysisResult result;

  const _FocusAnalysisBody({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _QualityCard(result: result),

        const SizedBox(height: 16),

        _SessionSummaryCard(result: result),

        const SizedBox(height: 24),

        Text(
          'Top interrupter',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 10),

        _TopInterrupterCard(result: result),

        const SizedBox(height: 24),

        Text(
          'Interruption timeline',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 6),

        Text(
          'Distracting apps detected during this focus session.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),

        const SizedBox(height: 12),

        _InterruptionTimeline(interruptions: result.interruptions),
      ],
    );
  }
}

class _QualityCard extends StatelessWidget {
  final FocusAnalysisResult result;

  const _QualityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final quality = result.focusQuality.round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: result.focusQuality / 100,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                ),

                Text(
                  '$quality%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Focus quality',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 5),

                Text(
                  '${_formatDuration(result.effectiveFocusDuration)} effective focus from ${_formatDuration(result.plannedDuration)} planned.',
                  style: TextStyle(
                    height: 1.4,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  final FocusAnalysisResult result;

  const _SessionSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus session',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 4),

          Text(
            '${_formatTime(result.focusStart)} – ${_formatTime(result.focusEnd)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Planned',
                  value: _formatDuration(result.plannedDuration),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Effective',
                  value: _formatDuration(result.effectiveFocusDuration),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Distracted',
                  value: _formatDuration(result.distractedDuration),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Interruptions',
                  value: '${result.interruptionCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.50),
          ),
        ),
      ],
    );
  }
}

class _TopInterrupterCard extends StatelessWidget {
  final FocusAnalysisResult result;

  const _TopInterrupterCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final appName = result.topInterrupterApp;

    if (appName == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('No distracting apps detected.'),
      );
    }

    final duration = result.distractionByApp[appName] ?? Duration.zero;
    String? appId;
    for (final interruption in result.interruptions) {
      if (interruption.appName == appName) {
        appId = interruption.appId;
        break;
      }
    }
    appId ??= usageProvider.resolveAppIdForName(appName);
    final displayName = appId == null
        ? appName
        : usageProvider.resolveDisplayName(appId, fallback: appName);
    final iconBytes =
        appId == null ? null : usageProvider.getAppMetadata(appId)?.iconBytes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AppIcon(
            iconBytes: iconBytes,
            appName: displayName,
            size: 48,
            borderRadius: 14,
            fallbackBackground: Colors.orange.withOpacity(0.12),
            fallbackForeground: Colors.orange,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${_formatDuration(duration)} of distraction',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterruptionTimeline extends StatelessWidget {
  final List<FocusInterruption> interruptions;

  const _InterruptionTimeline({required this.interruptions});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();

    if (interruptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('No interruptions detected. Great work!'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: List.generate(interruptions.length, (index) {
          final interruption = interruptions[index];

          return Column(
            children: [
              Row(
                children: [
                  AppIcon(
                    iconBytes: usageProvider
                        .getAppMetadata(interruption.appId)
                        ?.iconBytes,
                    appName: usageProvider.resolveDisplayName(
                      interruption.appId,
                      fallback: interruption.appName,
                    ),
                    size: 30,
                    borderRadius: 9,
                    fallbackBackground:
                        AppTheme.primaryBlue.withOpacity(0.12),
                    fallbackForeground: AppTheme.primaryBlue,
                  ),

                  const SizedBox(width: 10),

                  SizedBox(
                    width: 72,
                    child: Text(
                      _formatTime(interruption.startTime),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      usageProvider.resolveDisplayName(
                        interruption.appId,
                        fallback: interruption.appName,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),

                  Text(
                    _formatDuration(interruption.duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),

              if (index != interruptions.length - 1) const Divider(height: 28),
            ],
          );
        }),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours == 0) {
    return '${remainingMinutes}m';
  }

  if (remainingMinutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${remainingMinutes}m';
}

String _formatTime(DateTime dateTime) {
  int hour = dateTime.hour;

  final minute = dateTime.minute.toString().padLeft(2, '0');

  final period = hour >= 12 ? 'PM' : 'AM';

  if (hour == 0) {
    hour = 12;
  } else if (hour > 12) {
    hour -= 12;
  }

  return '$hour:$minute $period';
}

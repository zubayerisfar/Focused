import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_analysis_result.dart';
import '../../models/focus_interruption.dart';
import '../../providers/focus_provider.dart';
import '../../providers/usage_provider.dart';
import '../../services/ad_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import 'advanced_focus_analysis_screen.dart';

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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
            OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
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

        const SizedBox(height: 18),

        _AdvancedAnalysisAdCard(result: result),

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
    final quality = result.focusQuality.clamp(0, 100).round();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final ringColor = quality >= 80
        ? const Color(0xFF10B981)
        : quality >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ringColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          _FocusQualityRing(
            size: 96,
            quality: quality,
            ringColor: ringColor,
            progress: (result.focusQuality / 100).clamp(0.0, 1.0),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Focus quality',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatDuration(result.effectiveFocusDuration)} effective focus from ${_formatDuration(result.plannedDuration)} planned.',
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
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

class _FocusQualityRing extends StatelessWidget {
  final double size;
  final int quality;
  final Color ringColor;
  final double progress;

  const _FocusQualityRing({
    required this.size,
    required this.quality,
    required this.ringColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QualityRingPainter(
          progress: progress,
          color: ringColor,
          trackColor: ringColor.withValues(alpha: 0.15),
          strokeWidth: 8.5,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$quality%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ringColor,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'QUALITY',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _QualityRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw background track
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc (starting from top, clockwise)
    if (progress > 0) {
      final sweepAngle = 2 * 3.141592653589793 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QualityRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
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

class _AdvancedAnalysisAdCard extends StatelessWidget {
  final FocusAnalysisResult result;

  const _AdvancedAnalysisAdCard({required this.result});

  void _openAdvancedReport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvancedFocusAnalysisScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF31104B)]
              : [const Color(0xFFF3E8FF), const Color(0xFFEDE9FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deep Dive Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Attention retention & app distraction breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                AdService.instance.showRewardedAd(
                  onUserEarnedReward: (_) {
                    _openAdvancedReport(context);
                  },
                );
              },
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text(
                'Watch Ad for Advanced Analysis',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
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
    final iconBytes = appId == null
        ? null
        : usageProvider.getAppMetadata(appId)?.iconBytes;

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
                    fallbackBackground: AppTheme.primaryBlue.withOpacity(0.12),
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

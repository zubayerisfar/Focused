import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_analysis_result.dart';
import '../../models/focus_interruption.dart';
import '../../providers/usage_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

class AdvancedFocusAnalysisScreen extends StatelessWidget {
  final FocusAnalysisResult result;

  const AdvancedFocusAnalysisScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final quality = result.focusQuality.clamp(0, 100).round();
    final retention = result.attentionRetention.clamp(0, 100).round();
    final completion = result.completionRate.clamp(0, 100).round();

    final qualityColor = quality >= 80
        ? const Color(0xFF10B981)
        : quality >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Advanced Focus Report',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          // Hero Summary Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: qualityColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _FocusQualityRing(
                      size: 96,
                      quality: quality,
                      ringColor: qualityColor,
                      progress: (result.focusQuality / 100).clamp(0.0, 1.0),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quality >= 80
                                ? 'Elite Focus Level 🏆'
                                : quality >= 50
                                ? 'Moderate Concentration ⚡'
                                : 'High Distraction Session ⚠️',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_formatDuration(result.effectiveFocusDuration)} pure productivity from ${_formatDuration(result.plannedDuration)} planned.',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricStat(
                      label: 'Retention',
                      value: '$retention%',
                      icon: Icons.psychology_rounded,
                      color: const Color(0xFF6366F1),
                    ),
                    _MetricStat(
                      label: 'Completion',
                      value: '$completion%',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    _MetricStat(
                      label: 'Interrupts',
                      value: '${result.interruptionCount}',
                      icon: Icons.notifications_paused_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Deep Dive Time Breakdown
          Text(
            'Session Time Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                _TimeBarRow(
                  label: 'Effective Focused Time',
                  duration: result.effectiveFocusDuration,
                  total: result.plannedDuration,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 14),
                _TimeBarRow(
                  label: 'Distraction & Interruption',
                  duration: result.distractedDuration,
                  total: result.plannedDuration,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(height: 14),
                _TimeBarRow(
                  label: 'Total Planned Target',
                  duration: result.plannedDuration,
                  total: result.plannedDuration,
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Distraction By App Breakdown
          Text(
            'Distraction By App',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DistractionByAppList(distractions: result.distractionByApp),

          const SizedBox(height: 26),

          // Full Timeline of Events
          Text(
            'Interruption Log',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _InterruptionLogList(interruptions: result.interruptions),
        ],
      ),
    );
  }
}

class _MetricStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TimeBarRow extends StatelessWidget {
  final String label;
  final Duration duration;
  final Duration total;
  final Color color;

  const _TimeBarRow({
    required this.label,
    required this.duration,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = total.inSeconds > 0
        ? (duration.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DistractionByAppList extends StatelessWidget {
  final Map<String, Duration> distractions;

  const _DistractionByAppList({required this.distractions});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (distractions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: const Center(child: Text('Zero distractions recorded! 🎯')),
      );
    }

    final sortedEntries = distractions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: sortedEntries.map((entry) {
          final appId = entry.key;
          final duration = entry.value;
          final displayName = usageProvider.resolveDisplayName(
            appId,
            fallback: appId,
          );
          final iconBytes = usageProvider.getAppMetadata(appId)?.iconBytes;

          return ListTile(
            leading: AppIcon(
              iconBytes: iconBytes,
              appName: displayName,
              size: 38,
              borderRadius: 10,
              fallbackBackground: Colors.orange.withValues(alpha: 0.15),
              fallbackForeground: Colors.orange,
            ),
            title: Text(
              displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            trailing: Text(
              _formatDuration(duration),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFEF4444),
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InterruptionLogList extends StatelessWidget {
  final List<FocusInterruption> interruptions;

  const _InterruptionLogList({required this.interruptions});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (interruptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: const Center(
          child: Text('No interruptions occurred during this session.'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: interruptions.asMap().entries.map((indexed) {
          final index = indexed.key;
          final interruption = indexed.value;
          final name = usageProvider.resolveDisplayName(
            interruption.appId,
            fallback: interruption.appName,
          );
          final iconBytes = usageProvider
              .getAppMetadata(interruption.appId)
              ?.iconBytes;

          return Column(
            children: [
              ListTile(
                leading: AppIcon(
                  iconBytes: iconBytes,
                  appName: name,
                  size: 34,
                  borderRadius: 10,
                  fallbackBackground: AppTheme.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                  fallbackForeground: AppTheme.primaryBlue,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Started at ${_formatTime(interruption.startTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  _formatDuration(interruption.duration),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
              if (index < interruptions.length - 1)
                Divider(height: 1, indent: 64, color: themeDivider(context)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color themeDivider(BuildContext context) => Theme.of(context).dividerColor;
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

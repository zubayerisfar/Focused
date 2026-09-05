import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_usage_app_entry.dart';
import '../../../core/widgets/app_icon.dart';

class AnimatedAppUsage3DChart extends StatelessWidget {
  const AnimatedAppUsage3DChart({
    super.key,
    required this.entries,
    required this.onAppTap,
  });

  final List<AppUsageAppEntry> entries;
  final ValueChanged<AppUsageAppEntry> onAppTap;

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList(growable: false);
    if (top.isEmpty) {
      return const SizedBox.shrink();
    }

    var maxSeconds = 1;
    for (final entry in top) {
      if (entry.duration.inSeconds > maxSeconds) {
        maxSeconds = entry.duration.inSeconds;
      }
    }

    final palette = <Color>[
      const Color(0xFF6F9AFF),
      const Color(0xFF38C5C8),
      const Color(0xFF9B86F5),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return SizedBox(
          height: 238,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(top.length, (index) {
              final entry = top[index];
              final ratio = entry.duration.inSeconds / maxSeconds;
              final delay = index * 0.10;
              final progress = ((animation - delay) / (1 - delay))
                  .clamp(0.0, 1.0)
                  .toDouble();

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 5,
                    right: index == top.length - 1 ? 0 : 5,
                  ),
                  child: _Animated3DBar(
                    entry: entry,
                    progress: progress,
                    heightRatio: ratio.clamp(0.18, 1.0).toDouble(),
                    color: palette[index % palette.length],
                    onTap: () => onAppTap(entry),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _Animated3DBar extends StatelessWidget {
  const _Animated3DBar({
    required this.entry,
    required this.progress,
    required this.heightRatio,
    required this.color,
    required this.onTap,
  });

  final AppUsageAppEntry entry;
  final double progress;
  final double heightRatio;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barHeight = (48 + (100 * heightRatio)) * progress;
    final iconBottom = 55 + barHeight - 15;

    return Semantics(
      button: true,
      label: '${_cleanAppName(entry.appName)}, ${_formatDuration(entry.duration)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 52,
              left: 8,
              right: 8,
              child: SizedBox(
                height: barHeight + 20,
                child: CustomPaint(
                  painter: _Pseudo3DBarPainter(
                    color: color,
                    barHeight: barHeight,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: iconBottom.clamp(56.0, 188.0).toDouble(),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: progress > 0.35 ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black.withOpacity(0.16),
                      ),
                    ],
                  ),
                  child: AppIcon(
                    iconBytes: entry.iconBytes,
                    appName: _cleanAppName(entry.appName),
                    size: 28,
                    borderRadius: 8,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 2,
              right: 2,
              bottom: 0,
              child: Column(
                children: [
                  Text(
                    _cleanAppName(entry.appName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(entry.duration),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pseudo3DBarPainter extends CustomPainter {
  const _Pseudo3DBarPainter({
    required this.color,
    required this.barHeight,
  });

  final Color color;
  final double barHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (barHeight <= 0 || size.width <= 0) return;

    const depth = 10.0;
    final width = math.min(54.0, size.width - 22);
    final left = (size.width - width - depth) / 2;
    final bottom = size.height;
    final top = bottom - barHeight;

    final front = Rect.fromLTWH(left, top, width, barHeight);
    final frontPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, const Radius.circular(5)),
      frontPaint,
    );

    final side = Path()
      ..moveTo(left + width, top)
      ..lineTo(left + width + depth, top - depth * 0.55)
      ..lineTo(left + width + depth, bottom - depth * 0.55)
      ..lineTo(left + width, bottom)
      ..close();
    canvas.drawPath(
      side,
      Paint()..color = Color.lerp(color, Colors.black, 0.26)!,
    );

    final topFace = Path()
      ..moveTo(left, top)
      ..lineTo(left + depth, top - depth * 0.55)
      ..lineTo(left + width + depth, top - depth * 0.55)
      ..lineTo(left + width, top)
      ..close();
    canvas.drawPath(
      topFace,
      Paint()..color = Color.lerp(color, Colors.white, 0.28)!,
    );

    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(front);
    canvas.drawRRect(
      RRect.fromRectAndRadius(front, const Radius.circular(5)),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _Pseudo3DBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.barHeight != barHeight;
  }
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
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Unknown app';
  if (!trimmed.contains('.')) return trimmed;
  return trimmed.split('.').last.replaceAll('_', ' ');
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/widgets/glass_container.dart';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

/// Glossy Glass Daily Focus & Progress Card (Without digital wellbeing / app usage)
class DailyOverviewCard extends StatelessWidget {
  final Duration focusedToday;
  final double? focusComparisonPercent;
  final int completedTasksCount;
  final int totalTasksCount;

  const DailyOverviewCard({
    super.key,
    required this.focusedToday,
    required this.focusComparisonPercent,
    this.completedTasksCount = 0,
    this.totalTasksCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double completionPercent = totalTasksCount > 0
        ? (completedTasksCount / totalTasksCount).clamp(0.0, 1.0)
        : (completedTasksCount > 0 ? 1.0 : 0.0);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Progress",
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalTasksCount == 0
                        ? "Plan tasks to track progress"
                        : "$completedTasksCount of $totalTasksCount tasks completed",
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              // Circular progress ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: totalTasksCount > 0 ? completionPercent : 0.05,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completionPercent >= 1.0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  Text(
                    '${(completionPercent * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Metric chips in glossy capsule row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.14)
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                          : const Color(0xFFC4B5FD).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icon/focus_icon.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Focused',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF6B21A8),
                              ),
                            ),
                            Text(
                              _formatDuration(focusedToday),
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF4C1D95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.14)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFF6EE7B7).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF047857),
                              ),
                            ),
                            Text(
                              '$completedTasksCount Tasks',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

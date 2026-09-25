import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/glass_container.dart';

/// Clean, frosted Glass Motivational Hero Banner without harsh gradient coloring
class MotivationalHeroBanner extends StatelessWidget {
  final int pendingTasks;

  const MotivationalHeroBanner({super.key, required this.pendingTasks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMM').format(now);

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFF6366F1).withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
              // Status pill (All Clear vs In Progress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pendingTasks <= 0
                      ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1)
                      : const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  pendingTasks <= 0 ? 'All Clear ✨' : '$pendingTasks In Progress',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: pendingTasks <= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Today’s Plan',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            pendingTasks <= 0
                ? 'You have no tasks for today.'
                : (pendingTasks == 1
                      ? 'You have 1 task for today.'
                      : 'You have $pendingTasks tasks for today.'),
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

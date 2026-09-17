import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Glossy Gradient Motivational Hero Banner inspired by the TaskityAI reference design
class MotivationalHeroBanner extends StatelessWidget {
  final int pendingTasks;

  const MotivationalHeroBanner({super.key, required this.pendingTasks});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('d MMM').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A59), Color(0xFFE879F9), Color(0xFF818CF8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A59).withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top pill: Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Today’s Plan',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            pendingTasks <= 0
                ? 'You have no tasks for today.'
                : (pendingTasks == 1
                      ? 'You have 1 task for today.'
                      : 'You have $pendingTasks tasks for today.'),
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

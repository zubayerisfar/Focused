import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/glass_container.dart';

/// Interactive 7-Day Date Selector Strip inspired by modern calendar UI
class WeeklyDateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeeklyDateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    // Generate dates from today - 2 to today + 4 (7 days window)
    final dates = List.generate(7, (index) {
      return DateTime(now.year, now.month, now.day - 2 + index);
    });

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: dates.map((date) {
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;

          final dayName = DateFormat('E').format(date);
          final dayNumber = DateFormat('d').format(date);

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (isDark ? Colors.white : const Color(0xFF1E293B))
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? (isDark ? Colors.black87 : Colors.white)
                          : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNumber,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

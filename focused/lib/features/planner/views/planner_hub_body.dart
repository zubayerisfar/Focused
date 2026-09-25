import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../habits/providers/habit_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_provider.dart';

enum PlannerArea { hub, tasks, reminders, habits }

class PlannerHubBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<PlannerArea> onSelectArea;
  final VoidCallback onPickDate;

  const PlannerHubBody({
    super.key,
    required this.selectedDate,
    required this.onSelectArea,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final taskProvider = context.watch<TaskProvider>();
    final habitProvider = context.watch<HabitProvider>();

    // 1. Task Metrics
    final dateTasks = taskProvider.tasksForDate(
      selectedDate,
      includeCompleted: true,
    );
    final completedTasks = dateTasks
        .where((t) => taskProvider.isTaskCompletedForDate(t, selectedDate))
        .length;
    final pendingTasks = dateTasks.length - completedTasks;
    final totalCritical = dateTasks
        .where((t) => t.priority == TaskPriority.critical)
        .length;
    final activeCritical = dateTasks
        .where(
          (t) =>
              t.priority == TaskPriority.critical &&
              !taskProvider.isTaskCompletedForDate(t, selectedDate),
        )
        .length;

    // 2. Reminder Metrics
    final dateReminders = taskProvider.remindersForDate(
      selectedDate,
      includeCompleted: true,
    );
    final completedReminders = dateReminders
        .where((r) => taskProvider.isTaskCompletedForDate(r, selectedDate))
        .length;
    final pendingReminders = dateReminders.length - completedReminders;

    Task? nextReminder;
    for (final r in dateReminders) {
      if (!taskProvider.isTaskCompletedForDate(r, selectedDate) &&
          r.scheduledStart != null) {
        if (nextReminder == null ||
            r.scheduledStart!.isBefore(nextReminder.scheduledStart!)) {
          nextReminder = r;
        }
      }
    }

    // 3. Habit Metrics
    final dateHabits = habitProvider.habitsForDate(selectedDate);
    final completedHabits = dateHabits
        .where((h) => habitProvider.isCompletedForDate(h, selectedDate))
        .length;
    final pendingHabits = dateHabits.length - completedHabits;
    final habitProgressRate = dateHabits.isEmpty
        ? 0.0
        : (completedHabits / dateHabits.length).clamp(0.0, 1.0);

    final isToday = _isSameDay(selectedDate, DateTime.now());
    final dateDisplay = isToday
        ? 'Today, ${DateFormat('d MMMM').format(selectedDate)}'
        : DateFormat('EEEE, d MMMM').format(selectedDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
      children: [
        // ── Top Date Filter Banner ──
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2433).withValues(alpha: 0.85)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFF6366F1).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLANNING HORIZON',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isDark
                              ? const Color(0xFFA5B4FC)
                              : const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateDisplay,
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // ══════════════════════════════════════════════════════════════
        // TILE 1: Tasks & Schedule
        // ══════════════════════════════════════════════════════════════
        _ModernPlannerTile(
          title: 'Tasks & Schedule',
          subtitle: 'Daily agenda, time blocks, and timeline',
          svgAsset: 'assets/planner_page_icons/task_icon.svg',
          fallbackIcon: Icons.calendar_today_rounded,
          accentColor: const Color(0xFF6366F1),
          gradientColors: isDark
              ? [const Color(0xFF1E1D38), const Color(0xFF161726)]
              : [const Color(0xFFF3F2FF), const Color(0xFFFAF9FF)],
          totalCount: dateTasks.length,
          completedCount: completedTasks,
          onTapCard: () => onSelectArea(PlannerArea.tasks),
          chips: [
            _TileChip(
              icon: Icons.checklist_rounded,
              label: '${dateTasks.length} ${dateTasks.length == 1 ? 'Task' : 'Tasks'}',
              color: const Color(0xFF6366F1),
            ),
            if (activeCritical > 0)
              _TileChip(
                icon: Icons.local_fire_department_rounded,
                label: '$activeCritical Critical',
                color: const Color(0xFFEF4444),
                isHighImpact: true,
              )
            else if (totalCritical > 0)
              const _TileChip(
                icon: Icons.check_circle_rounded,
                label: 'Critical Done',
                color: Color(0xFF10B981),
              ),
            _TileChip(
              icon: Icons.hourglass_top_rounded,
              label: '$pendingTasks Pending',
              color: const Color(0xFF6366F1),
            ),
            if (completedTasks > 0)
              _TileChip(
                icon: Icons.task_alt_rounded,
                label: '$completedTasks Done',
                color: const Color(0xFF10B981),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ══════════════════════════════════════════════════════════════
        // TILE 2: Reminders & Alerts
        // ══════════════════════════════════════════════════════════════
        _ModernPlannerTile(
          title: 'Reminders & Alerts',
          subtitle: null,
          svgAsset: 'assets/planner_page_icons/reminder_icon.svg',
          fallbackIcon: Icons.notifications_active_rounded,
          accentColor: const Color(0xFFFF9600),
          gradientColors: isDark
              ? [const Color(0xFF332313), const Color(0xFF1F1916)]
              : [const Color(0xFFFFF7ED), const Color(0xFFFFFDF9)],
          totalCount: dateReminders.length,
          completedCount: completedReminders,
          onTapCard: () => onSelectArea(PlannerArea.reminders),
          chips: [
            _TileChip(
              icon: Icons.notifications_active_rounded,
              label: '${dateReminders.length} ${dateReminders.length == 1 ? 'Reminder' : 'Reminders'}',
              color: const Color(0xFFFF9600),
            ),
            _TileChip(
              icon: Icons.alarm_rounded,
              label: '$pendingReminders Active',
              color: const Color(0xFFFF9600),
            ),
            if (completedReminders > 0)
              _TileChip(
                icon: Icons.check_circle_rounded,
                label: '$completedReminders Done',
                color: const Color(0xFF10B981),
              ),
            if (nextReminder != null && nextReminder.scheduledStart != null)
              _TileChip(
                icon: Icons.schedule_rounded,
                label: 'Next: ${DateFormat.jm().format(nextReminder.scheduledStart!)}',
                color: const Color(0xFFFF9600),
                isHighImpact: true,
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ══════════════════════════════════════════════════════════════
        // TILE 3: Habits & Routines
        // ══════════════════════════════════════════════════════════════
        _ModernPlannerTile(
          title: 'Habits & Routines',
          subtitle: 'Daily streak building, recurring check-ins, and goals',
          svgAsset: 'assets/planner_page_icons/habit_icon.svg',
          fallbackIcon: Icons.repeat_rounded,
          accentColor: const Color(0xFF10B981),
          gradientColors: isDark
              ? [const Color(0xFF132B24), const Color(0xFF141D1A)]
              : [const Color(0xFFECFDF5), const Color(0xFFF9FFFC)],
          totalCount: dateHabits.length,
          completedCount: completedHabits,
          onTapCard: () => onSelectArea(PlannerArea.habits),
          chips: [
            _TileChip(
              icon: Icons.repeat_rounded,
              label: '${dateHabits.length} ${dateHabits.length == 1 ? 'Habit' : 'Habits'}',
              color: const Color(0xFF10B981),
            ),
            _TileChip(
              icon: Icons.task_alt_rounded,
              label: '$completedHabits / ${dateHabits.length} Done',
              color: const Color(0xFF10B981),
            ),
            if (dateHabits.isNotEmpty)
              _TileChip(
                icon: Icons.trending_up_rounded,
                label: '${(habitProgressRate * 100).toInt()}% Adherence',
                color: const Color(0xFF10B981),
              ),
            if (pendingHabits > 0)
              _TileChip(
                icon: Icons.timelapse_rounded,
                label: '$pendingHabits Remaining',
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
          ],
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODERN EXPANSIVE PLANNER TILE
// ══════════════════════════════════════════════════════════════════════════════
class _ModernPlannerTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? svgAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final List<Color> gradientColors;
  final int totalCount;
  final int completedCount;
  final VoidCallback onTapCard;
  final List<Widget> chips;

  const _ModernPlannerTile({
    required this.title,
    this.subtitle,
    this.svgAsset,
    this.fallbackIcon = Icons.star_rounded,
    required this.accentColor,
    required this.gradientColors,
    required this.totalCount,
    required this.completedCount,
    required this.onTapCard,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final progressRatio = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTapCard,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : accentColor.withValues(alpha: 0.20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : accentColor.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row: Icon, Title, and Chevron Arrow ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.22 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: svgAsset != null
                          ? SvgPicture.asset(
                              svgAsset!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              placeholderBuilder: (_) => Icon(
                                fallbackIcon,
                                color: accentColor,
                                size: 28,
                              ),
                            )
                          : Icon(fallbackIcon, color: accentColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 18.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Forward arrow indicator to visit
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 26,
                    ),
                  ],
                ),

                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // ── Interactive Chips Row ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
                ],

                // ── Progress Bar & Ratio (only shown when there are items) ──
                if (totalCount > 0) ...[
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedCount of $totalCount completed',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${(progressRatio * 100).toInt()}%',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : accentColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INFORMATIVE CHIP PILL WITH ICON
// ══════════════════════════════════════════════════════════════════════════════
class _TileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isHighImpact;

  const _TileChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isHighImpact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHighImpact
            ? color.withValues(alpha: isDark ? 0.25 : 0.15)
            : color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isHighImpact
              ? color.withValues(alpha: isDark ? 0.5 : 0.35)
              : color.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

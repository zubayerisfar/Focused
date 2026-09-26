import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_banner_ad_widget.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomNavClearance = 66.0 + (bottomInset > 0 ? bottomInset + 4 : 14) + 36;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomNavClearance),
      children: [
        // ── TILE 1: Tasks & Schedule ──
        _ModernPlannerTile(
          title: 'Tasks & Schedule',
          svgAsset: 'assets/planner_page_icons/task_icon.svg',
          fallbackIcon: Icons.calendar_today_rounded,
          accentColor: const Color(0xFF6366F1),
          gradientColors: isDark
              ? [const Color(0xFF1E1D38), const Color(0xFF161726)]
              : [const Color(0xFFF3F2FF), const Color(0xFFFAF9FF)],
          totalCount: dateTasks.length,
          completedCount: completedTasks,
          onTap: () => onSelectArea(PlannerArea.tasks),
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

        const SizedBox(height: 18),

        // ── TILE 2: Reminders & Alerts ──
        _ModernPlannerTile(
          title: 'Reminders & Alerts',
          svgAsset: 'assets/planner_page_icons/reminder_icon.svg',
          fallbackIcon: Icons.notifications_active_rounded,
          accentColor: const Color(0xFFFF9600),
          gradientColors: isDark
              ? [const Color(0xFF332313), const Color(0xFF1F1916)]
              : [const Color(0xFFFFF7ED), const Color(0xFFFFFDF9)],
          totalCount: dateReminders.length,
          completedCount: completedReminders,
          onTap: () => onSelectArea(PlannerArea.reminders),
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

        const SizedBox(height: 18),

        // ── TILE 3: Habits & Routines ──
        _ModernPlannerTile(
          title: 'Habits & Routines',
          svgAsset: 'assets/planner_page_icons/habit_icon.svg',
          fallbackIcon: Icons.repeat_rounded,
          accentColor: const Color(0xFF10B981),
          gradientColors: isDark
              ? [const Color(0xFF132B24), const Color(0xFF141D1A)]
              : [const Color(0xFFECFDF5), const Color(0xFFF9FFFC)],
          totalCount: dateHabits.length,
          completedCount: completedHabits,
          onTap: () => onSelectArea(PlannerArea.habits),
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

        const SizedBox(height: 18),

        // ── Centered Banner Ad (Positioned Down Below Tiles) ──
        const AppBannerAdWidget(
          margin: EdgeInsets.only(top: 4, bottom: 10),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODERN EXPANSIVE PLANNER TILE (TALLER & CLEAN)
// ══════════════════════════════════════════════════════════════════════════════
class _ModernPlannerTile extends StatelessWidget {
  final String title;
  final String? svgAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final List<Color> gradientColors;
  final int totalCount;
  final int completedCount;
  final VoidCallback onTap;
  final List<Widget> chips;

  const _ModernPlannerTile({
    required this.title,
    this.svgAsset,
    this.fallbackIcon = Icons.star_rounded,
    required this.accentColor,
    required this.gradientColors,
    required this.totalCount,
    required this.completedCount,
    required this.onTap,
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
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 148),
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
                  : accentColor.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : accentColor.withValues(alpha: 0.09),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Header: Icon, Title, and Rounded Chevron Button ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
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
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) => Icon(
                              fallbackIcon,
                              color: accentColor,
                              size: 26,
                            ),
                          )
                        : Icon(fallbackIcon, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 19.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : accentColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Informative Chips ──
              if (chips.isNotEmpty)
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: chips,
                ),

              // ── Progress Bar (only shown when there are items) ──
              if (totalCount > 0) ...[
                const SizedBox(height: 16),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${(progressRatio * 100).toInt()}%',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 6,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

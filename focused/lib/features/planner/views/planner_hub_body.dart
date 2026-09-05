import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PlannerArea { hub, tasks, reminders, habits }

class PlannerHubBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<PlannerArea> onSelectArea;
  final VoidCallback onPickDate;

  const PlannerHubBody({super.key, 
    required this.selectedDate,
    required this.onSelectArea,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        // CARD 1: Tasks & Schedule
        _BigPlannerCard(
          title: 'Tasks & Schedule',
          subtitle: 'Daily agenda, time blocks, and calendar timeline',
          svgAsset: 'assets/planner_page_icons/planner_task_creation.svg',
          fallbackIcon: Icons.calendar_today_rounded,
          accentColor: const Color(0xFF1CB0F6),
          gradientColors: isDark
              ? [const Color(0xFF132840), const Color(0xFF181D29)]
              : [const Color(0xFFEBF5FF), const Color(0xFFF6FAFF)],
          onTap: () => onSelectArea(PlannerArea.tasks),
        ),

        const SizedBox(height: 16),

        // CARD 2: Reminders
        _BigPlannerCard(
          title: 'Reminders',
          subtitle: 'Scheduled notifications, alerts, and time alarms',
          svgAsset: 'assets/planner_page_icons/planner_reminder_icon.svg',
          fallbackIcon: Icons.notifications_active_rounded,
          accentColor: const Color(0xFFFF9600),
          gradientColors: isDark
              ? [const Color(0xFF382510), const Color(0xFF221A15)]
              : [const Color(0xFFFFF6EB), const Color(0xFFFFFBF6)],
          onTap: () => onSelectArea(PlannerArea.reminders),
        ),

        const SizedBox(height: 16),

        // CARD 3: Habits & Routines
        _BigPlannerCard(
          title: 'Habits & Routines',
          subtitle: 'Daily streak building, recurring check-ins, and goals',
          svgAsset: 'assets/planner_page_icons/planner_habit_icon.svg',
          fallbackIcon: Icons.repeat_rounded,
          accentColor: const Color(0xFF9B51E0),
          gradientColors: isDark
              ? [const Color(0xFF2E1A3D), const Color(0xFF1F1728)]
              : [const Color(0xFFF7F0FF), const Color(0xFFFCF9FF)],
          onTap: () => onSelectArea(PlannerArea.habits),
        ),
      ],
    );
  }
}



class _BigPlannerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? svgAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _BigPlannerCard({
    required this.title,
    required this.subtitle,
    this.svgAsset,
    this.fallbackIcon = Icons.star_rounded,
    required this.accentColor,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.35 : 0.6,
              ),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.22 : 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: svgAsset != null
                    ? SvgPicture.asset(
                        svgAsset!,
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        placeholderBuilder: (_) =>
                            Icon(fallbackIcon, color: accentColor, size: 30),
                      )
                    : Icon(fallbackIcon, color: accentColor, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../settings/providers/cloud_sync_provider.dart';
import '../views/planner_hub_body.dart';

enum PlannerCalendarMode { schedule, day, threeDays, week, month }

extension PlannerCalendarModeLabel on PlannerCalendarMode {
  String get label {
    switch (this) {
      case PlannerCalendarMode.schedule:
        return 'Create your plan';
      case PlannerCalendarMode.day:
        return 'Day';
      case PlannerCalendarMode.threeDays:
        return '3 days';
      case PlannerCalendarMode.week:
        return 'Week';
      case PlannerCalendarMode.month:
        return 'Month';
    }
  }

  IconData get icon {
    switch (this) {
      case PlannerCalendarMode.schedule:
        return Icons.view_agenda_outlined;
      case PlannerCalendarMode.day:
        return Icons.view_day_outlined;
      case PlannerCalendarMode.threeDays:
        return Icons.view_week_outlined;
      case PlannerCalendarMode.week:
        return Icons.calendar_view_week_outlined;
      case PlannerCalendarMode.month:
        return Icons.calendar_month_outlined;
    }
  }
}

enum PlannerMenuAction { backlog, completed }

class PlannerHeader extends StatelessWidget {
  final DateTime selectedDate;
  final PlannerArea area;
  final PlannerCalendarMode calendarMode;
  final VoidCallback onPickDate;
  final VoidCallback onToday;
  final ValueChanged<PlannerCalendarMode> onModeChanged;
  final VoidCallback onSync;
  final ValueChanged<PlannerMenuAction> onMenuAction;
  final VoidCallback? onBackToHub;

  const PlannerHeader({super.key, 
    required this.selectedDate,
    required this.area,
    required this.calendarMode,
    required this.onPickDate,
    required this.onToday,
    required this.onModeChanged,
    required this.onSync,
    required this.onMenuAction,
    this.onBackToHub,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sync = context.watch<CloudSyncProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Row(
        children: [
          if (area != PlannerArea.hub) ...[
            IconButton(
              tooltip: 'Back to Planner Hub',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBackToHub,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                area == PlannerArea.hub
                    ? 'Planner'
                    : (area == PlannerArea.tasks
                          ? 'Tasks'
                          : (area == PlannerArea.reminders
                                ? 'Reminders'
                                : 'Habits')),
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          _PlannerHeaderIconButton(
            tooltip: 'Today',
            onPressed: onToday,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${DateTime.now().day}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _PlannerHeaderIconButton(
            tooltip: sync.isSyncing ? 'Syncing…' : 'Sync planner',
            onPressed: sync.canSync ? onSync : null,
            child: sync.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
          ),
          if (area == PlannerArea.tasks)
            PopupMenuButton<PlannerCalendarMode>(
              tooltip: 'Calendar view: ${calendarMode.label}',
              initialValue: calendarMode,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onSelected: onModeChanged,
              itemBuilder: (context) {
                return PlannerCalendarMode.values.map((mode) {
                  return PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(mode.icon, size: 21),
                        const SizedBox(width: 14),
                        Text(
                          mode.label,
                          style: TextStyle(
                            fontWeight: mode == calendarMode
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(calendarMode.icon, size: 20),
              ),
            ),
          PopupMenuButton<PlannerMenuAction>(
            tooltip: 'More',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onSelected: onMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: PlannerMenuAction.backlog,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Backlog'),
                ),
              ),
              PopupMenuItem(
                value: PlannerMenuAction.completed,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.done_all_rounded),
                  title: Text('Completed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlannerHeaderIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  const _PlannerHeaderIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: child,
    );
  }
}


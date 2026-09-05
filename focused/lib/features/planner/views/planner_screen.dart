import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/task.dart';
import '../../../providers/cloud_sync_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_banner_ad_widget.dart';
import '../../habits/views/habit_planner_body.dart';
import '../../reminders/views/reminders_planner_body.dart';
import '../../planner/views/planner_hub_body.dart';
import '../../planner/widgets/planner_header.dart';
import '../../tasks/views/task_calendar_body.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  PlannerArea _area = PlannerArea.hub;
  PlannerCalendarMode _calendarMode = PlannerCalendarMode.schedule;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final isDark = baseTheme.brightness == Brightness.dark;
    final taskAccent = isDark
        ? const Color(0xFF6F9AFF)
        : const Color(0xFF4169D8);
    final reminderAccent = const Color(0xFFFF9600);
    final habitAccent = isDark
        ? const Color(0xFFC39BFF)
        : const Color(0xFF7B55C7);
    final accent = _area == PlannerArea.tasks
        ? taskAccent
        : (_area == PlannerArea.reminders ? reminderAccent : habitAccent);
    final selectedBackground = isDark
        ? accent.withValues(alpha: 0.30)
        : accent.withValues(alpha: 0.14);
    final pageTint = _area == PlannerArea.tasks
        ? (isDark ? const Color(0xFF0F1A28) : const Color(0xFFF2F7FD))
        : (isDark
              ? accent.withValues(alpha: 0.035)
              : accent.withValues(alpha: 0.045));
    final plannerTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accent,
        primaryContainer: selectedBackground,
      ),
    );

    return PopScope(
      canPop: _area == PlannerArea.hub,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() {
            _area = PlannerArea.hub;
          });
        }
      },
      child: Theme(
        data: plannerTheme,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF171A23)
                          : baseTheme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.40 : 0.08,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: PlannerHeader(
                      selectedDate: _selectedDate,
                      area: _area,
                      calendarMode: _calendarMode,
                      onPickDate: _pickDate,
                      onToday: () {
                        setState(() {
                          _selectedDate = _dateOnly(DateTime.now());
                        });
                      },
                      onModeChanged: (mode) {
                        setState(() {
                          _calendarMode = mode;
                        });
                      },
                      onSync: _syncPlanner,
                      onMenuAction: _handleMenuAction,
                      onBackToHub: () {
                        setState(() {
                          _area = PlannerArea.hub;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(color: pageTint, child: _buildAreaBody()),
                  ),
                  if (_area != PlannerArea.tasks) const AppBannerAdWidget(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaBody() {
    switch (_area) {
      case PlannerArea.hub:
        return PlannerHubBody(
          selectedDate: _selectedDate,
          onSelectArea: (area) {
            setState(() {
              _area = area;
            });
          },
          onPickDate: _pickDate,
        );
      case PlannerArea.tasks:
        return TaskCalendarBody(
          mode: _calendarMode,
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = _dateOnly(date);
            });
          },
          onPickDate: _pickDate,
        );
      case PlannerArea.reminders:
        return RemindersPlannerBody(
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = _dateOnly(date);
            });
          },
        );
      case PlannerArea.habits:
        return HabitPlannerBody(
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = _dateOnly(date);
            });
          },
        );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = _dateOnly(picked);
    });
  }

  Future<void> _syncPlanner() async {
    final sync = context.read<CloudSyncProvider>();
    if (!sync.canSync) return;

    try {
      final result = await sync.syncNow(
        mode: CloudSyncMode.uploadOnly,
        isManual: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded to cloud · ${result.pushed} changes synced'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sync.errorMessage ?? 'Planner sync could not finish.'),
        ),
      );
    }
  }

  void _handleMenuAction(PlannerMenuAction action) {
    switch (action) {
      case PlannerMenuAction.backlog:
        _showTaskCollectionSheet(
          context,
          title: 'Backlog',
          tasks: context.read<TaskProvider>().plannerBacklog(),
        );
        return;
      case PlannerMenuAction.completed:
        _showCompletedSheet(context);
        return;
    }
  }
}

Future<void> _showTaskCollectionSheet(
  BuildContext context, {
  required String title,
  required List<Task> tasks,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing here.',
                            style: Theme.of(sheetContext).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: task.plannedDate == null
                                  ? null
                                  : Text(
                                      DateFormat(
                                        'EEE, MMM d',
                                      ).format(task.plannedDate!),
                                    ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                context.push(
                                  '/task/${Uri.encodeComponent(task.id)}',
                                );
                              },
                              onLongPress: () {
                                Navigator.pop(sheetContext);
                                context.push(
                                  '/task/edit/${Uri.encodeComponent(task.id)}',
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showCompletedSheet(BuildContext context) {
  final provider = context.read<TaskProvider>();
  final oneTime = provider.plannerCompleted();
  final recurring = provider.completedRecurringOccurrences();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final itemCount = oneTime.length + recurring.length;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed',
                  style: Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: itemCount == 0
                      ? Center(
                          child: Text(
                            'Completed work will appear here.',
                            style: Theme.of(sheetContext).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView(
                          children: [
                            ...oneTime.map(
                              (task) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.success,
                                ),
                                title: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: task.completedAt == null
                                    ? null
                                    : Text(
                                        'Done ${DateFormat('MMM d, h:mm a').format(task.completedAt!)}',
                                      ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.push(
                                    '/task/${Uri.encodeComponent(task.id)}',
                                  );
                                },
                                onLongPress: () {
                                  Navigator.pop(sheetContext);
                                  context.push(
                                    '/task/edit/${Uri.encodeComponent(task.id)}',
                                  );
                                },
                              ),
                            ),
                            ...recurring.map(
                              (occurrence) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.repeat_rounded,
                                  color: AppTheme.success,
                                ),
                                title: Text(
                                  occurrence.task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Occurrence ${DateFormat('EEE, MMM d').format(occurrence.start)}',
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.push(
                                    '/task/${Uri.encodeComponent(occurrence.task.id)}?date=${_dateQuery(occurrence.start)}',
                                  );
                                },
                                onLongPress: () {
                                  Navigator.pop(sheetContext);
                                  context.push(
                                    '/task/edit/${Uri.encodeComponent(occurrence.task.id)}',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateQuery(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

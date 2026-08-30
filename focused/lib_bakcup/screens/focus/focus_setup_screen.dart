import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

class FocusSetupScreen extends StatefulWidget {
  final String? initialTaskId;
  final DateTime? initialOccurrenceDate;

  const FocusSetupScreen({
    super.key,
    this.initialTaskId,
    this.initialOccurrenceDate,
  });

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  String? _selectedTaskId;
  late DateTime _occurrenceDate;

  // Unscheduled tasks default to 60 minutes.
  // Scheduled tasks derive their default focus time from Start → End.
  int _totalMinutes = 60;

  int _focusMinutes = 50;
  int _breakMinutes = 10;

  bool _didInitializeFromTask = false;

  @override
  void initState() {
    super.initState();

    _selectedTaskId = widget.initialTaskId;
    final initial = widget.initialOccurrenceDate ?? DateTime.now();
    _occurrenceDate = DateTime(initial.year, initial.month, initial.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitializeFromTask) {
      return;
    }

    _didInitializeFromTask = true;

    final taskProvider = context.read<TaskProvider>();

    Task? task;

    // If Focus Setup was opened from a specific task,
    // load that exact task first.
    if (_selectedTaskId != null) {
      final candidate = taskProvider.getTaskById(_selectedTaskId!);

      if (candidate != null &&
          !taskProvider.isTaskCompletedForDate(
            candidate,
            _occurrenceDate,
          )) {
        task = candidate;
      }
    }

    // Otherwise use TaskProvider's recommended next task.
    if (task == null && widget.initialOccurrenceDate != null) {
      final dateTasks = taskProvider.tasksForDate(
        _occurrenceDate,
        includeCompleted: false,
      );
      if (dateTasks.isNotEmpty) {
        task = dateTasks.first;
      }
    }

    task ??= taskProvider.nextTask();

    if (task != null) {
      _selectedTaskId = task.id;
      if (widget.initialOccurrenceDate == null) {
        _occurrenceDate = _executionDateForTask(taskProvider, task);
      }

      _totalMinutes = _focusMinutesForTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    Task? selectedTask;

    if (_selectedTaskId != null) {
      final candidate = taskProvider.getTaskById(_selectedTaskId!);

      if (candidate != null &&
          !taskProvider.isTaskCompletedForDate(
            candidate,
            _occurrenceDate,
          )) {
        selectedTask = candidate;
      }
    }

    if (selectedTask == null && widget.initialOccurrenceDate != null) {
      final dateTasks = taskProvider.tasksForDate(
        _occurrenceDate,
        includeCompleted: false,
      );
      if (dateTasks.isNotEmpty) {
        selectedTask = dateTasks.first;
      }
    }
    selectedTask ??= taskProvider.nextTask();

    final selectedOccurrence = selectedTask == null
        ? null
        : taskProvider.occurrenceForTaskOnDate(
            selectedTask,
            _occurrenceDate,
          );
    final sessionPlan = _buildSessionPlan();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set Up Focus',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Plan your session',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Text(
            'Choose what you want to work on and how you want to focus.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 28),

          // =================================================
          // TASK
          // =================================================
          const _SectionTitle(title: 'Task'),

          const SizedBox(height: 12),

          _AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: _showTaskPicker,
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedTask == null
                      ? Icons.add_task_rounded
                      : Icons.task_alt_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: Text(
                selectedTask?.title ?? 'Choose a task',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                selectedTask == null
                    ? 'Create a task before starting focus'
                    : '${_taskDurationLabel(selectedTask)} • ${selectedTask.priority.label}${selectedOccurrence == null ? '' : ' • ${_occurrenceLabel(selectedOccurrence.start, selectedOccurrence.end)}'}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),

          if (selectedTask == null) ...[
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/task/new');
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a Task'),
              ),
            ),
          ],

          const SizedBox(height: 26),

          // =================================================
          // SESSION SETTINGS
          // =================================================
          const _SectionTitle(title: 'Session'),

          const SizedBox(height: 12),

          _AppCard(
            child: Column(
              children: [
                _SettingRow(
                  title: 'Total duration',
                  value: _formatDuration(_totalMinutes),
                  onTap: _showTotalDurationPicker,
                ),

                const Divider(height: 1),

                _SettingRow(
                  title: 'Focus block',
                  value: '$_focusMinutes min',
                  onTap: _showFocusDurationPicker,
                ),

                const Divider(height: 1),

                _SettingRow(
                  title: 'Break',
                  value: '$_breakMinutes min',
                  onTap: _showBreakDurationPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // =================================================
          // SESSION PLAN
          // =================================================
          Row(
            children: [
              const _SectionTitle(title: 'Session plan'),

              const Spacer(),

              Text(
                '${sessionPlan.where((item) => item.isWork).length} focus blocks',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.50),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _AppCard(
            child: Column(
              children: List.generate(sessionPlan.length, (index) {
                final item = sessionPlan[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == sessionPlan.length - 1 ? 0 : 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.isWork
                              ? AppTheme.primaryBlue.withOpacity(0.12)
                              : const Color(0xFF34B27B).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isWork
                              ? Icons.timer_rounded
                              : Icons.free_breakfast_rounded,
                          color: item.isWork
                              ? AppTheme.primaryBlue
                              : const Color(0xFF34B27B),
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          item.isWork ? 'Focus' : 'Break',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),

                      Text(
                        '${item.minutes} min',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 30),

          // =================================================
          // START SESSION
          // =================================================
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: selectedTask == null
                  ? null
                  : () {
                      final occurrence = context
                          .read<TaskProvider>()
                          .occurrenceForTaskOnDate(
                            selectedTask!,
                            _occurrenceDate,
                          );

                      context.read<FocusProvider>().startSession(
                        taskId: selectedTask!.id,
                        taskName: selectedTask.title,
                        taskOccurrenceDate: _occurrenceDate,
                        taskScheduledStart: occurrence?.start,
                        taskScheduledEnd: occurrence?.end,
                        totalFocusMinutes: _totalMinutes,
                        focusBlockMinutes: _focusMinutes,
                        breakMinutes: _breakMinutes,
                      );

                      context.push('/focus/session');
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Start Focus Session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SESSION PLAN
  // =========================================================

  List<_FocusPlanItem> _buildSessionPlan() {
    final plan = <_FocusPlanItem>[];

    var remainingMinutes = _totalMinutes;

    while (remainingMinutes > 0) {
      final currentFocusMinutes = remainingMinutes >= _focusMinutes
          ? _focusMinutes
          : remainingMinutes;

      plan.add(_FocusPlanItem(isWork: true, minutes: currentFocusMinutes));

      remainingMinutes -= currentFocusMinutes;

      // Break time is NOT counted toward total focus duration.
      // Add a break only when another focus block remains.
      if (remainingMinutes > 0 && _breakMinutes > 0) {
        plan.add(_FocusPlanItem(isWork: false, minutes: _breakMinutes));
      }
    }

    return plan;
  }

  // =========================================================
  // TASK PICKER
  // =========================================================

  void _showTaskPicker() {
    final taskProvider = context.read<TaskProvider>();
    final tasks = widget.initialOccurrenceDate != null
        ? taskProvider.tasksForDate(
            _occurrenceDate,
            includeCompleted: false,
          )
        : taskProvider.incompleteTasks
            .where(
              (task) => !taskProvider.isTaskCompletedForDate(
                task,
                _occurrenceDate,
              ),
            )
            .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You do not have any unfinished tasks yet.'),
          action: SnackBarAction(
            label: 'Create',
            onPressed: () {
              context.push('/task/new');
            },
          ),
        ),
      );

      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                'Choose task',
                textAlign: TextAlign.center,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 12),

              ...tasks.map((task) {
                final selected = task.id == _selectedTaskId;

                return ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _taskColor(task.priority).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: _taskColor(task.priority),
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${_taskDurationLabel(task)} • ${task.priority.label}',
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primaryBlue,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedTaskId = task.id;
                      if (widget.initialOccurrenceDate == null) {
                        _occurrenceDate = _executionDateForTask(
                          taskProvider,
                          task,
                        );
                      }

                      _totalMinutes = _focusMinutesForTask(task);
                    });

                    Navigator.pop(sheetContext);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // DURATION PICKERS
  // =========================================================

  void _showTotalDurationPicker() {
    _showOptions(
      title: 'Total duration',
      options: const ['30', '60', '90', '120', '180'],
      displayText: (value) {
        return _formatDuration(int.parse(value));
      },
      onSelected: (value) {
        setState(() {
          _totalMinutes = int.parse(value);
        });
      },
    );
  }

  void _showFocusDurationPicker() {
    _showOptions(
      title: 'Focus block',
      options: const ['25', '30', '45', '50', '60', '90'],
      displayText: (value) => '$value min',
      onSelected: (value) {
        setState(() {
          _focusMinutes = int.parse(value);
        });
      },
    );
  }

  void _showBreakDurationPicker() {
    _showOptions(
      title: 'Break',
      options: const ['5', '10', '15', '20'],
      displayText: (value) => '$value min',
      onSelected: (value) {
        setState(() {
          _breakMinutes = int.parse(value);
        });
      },
    );
  }

  void _showOptions({
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
    String Function(String value)? displayText,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 12),

                ...options.map((value) {
                  return ListTile(
                    title: Text(
                      displayText?.call(value) ?? value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      onSelected(value);

                      Navigator.pop(sheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  DateTime _executionDateForTask(TaskProvider provider, Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (provider.occurrenceForTaskOnDate(task, today) != null) {
      return today;
    }

    final next = provider.nextOccurrenceStartForTask(
      task,
      now.subtract(const Duration(seconds: 1)),
    );
    if (next != null) {
      return DateTime(next.year, next.month, next.day);
    }

    final planned = task.plannedDate;
    if (planned != null) {
      return DateTime(planned.year, planned.month, planned.day);
    }

    return today;
  }

  int _focusMinutesForTask(Task task) {
    return task.defaultFocusMinutes;
  }

  String _taskDurationLabel(Task task) {
    final scheduledMinutes = task.scheduledDurationMinutes;

    if (scheduledMinutes == null) {
      return 'Flexible duration';
    }

    return _formatDuration(scheduledMinutes);
  }

  String _occurrenceLabel(DateTime start, DateTime end) {
    final now = DateTime.now();
    final day = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayLabel = day == today
        ? 'Today'
        : '${day.month}/${day.day}';
    final startText = TimeOfDay.fromDateTime(start).format(context);
    final endText = TimeOfDay.fromDateTime(end).format(context);
    return '$dayLabel $startText–$endText';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;

    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  Color _taskColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.critical:
        return const Color(0xFFFF6B5E);

      case TaskPriority.important:
        return AppTheme.primaryBlue;

      case TaskPriority.growth:
        return const Color(0xFF34B27B);
    }
  }
}

// ===========================================================
// SESSION PLAN ITEM
// ===========================================================

class _FocusPlanItem {
  final bool isWork;
  final int minutes;

  const _FocusPlanItem({required this.isWork, required this.minutes});
}

// ===========================================================
// CARD
// ===========================================================

class _AppCard extends StatelessWidget {
  final Widget child;

  const _AppCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

// ===========================================================
// SETTING ROW
// ===========================================================

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 4),

          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}

// ===========================================================
// SECTION TITLE
// ===========================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

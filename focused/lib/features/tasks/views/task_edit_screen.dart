import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../models/task_reminder_result.dart';
import '../models/task_schedule_conflict.dart';
import '../providers/task_provider.dart';
import '../../../core/theme/app_theme.dart';

class TaskEditScreen extends StatefulWidget {
  final String? taskId;

  const TaskEditScreen({super.key, this.taskId});

  bool get isEditing => taskId != null;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  TaskPriority _priority = TaskPriority.important;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;

  bool _scheduleOnCalendar = false;
  late DateTime _scheduledDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);

  TaskRecurrence _recurrence = TaskRecurrence.none;
  Set<int> _customWeekdays = <int>{};
  int? _reminderMinutesBefore;
  bool _enableLateReminder = false;
  int _lateReminderMinutes = 30;
  int _guardWarningSeconds = 30;

  bool _isSaving = false;
  bool _didLoadExistingTask = false;
  bool _taskNotFound = false;
  Task? _originalTask;

  @override
  void initState() {
    super.initState();

    final today = _dateOnly(DateTime.now());
    _plannedDate = today;
    _deadlineDate = null;
    _scheduledDate = today;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadExistingTask) {
      return;
    }

    _didLoadExistingTask = true;

    final taskId = widget.taskId;
    if (taskId == null) {
      return;
    }

    final task = context.read<TaskProvider>().getTaskById(taskId);
    if (task == null) {
      _taskNotFound = true;
      return;
    }

    _originalTask = task;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _priority = task.priority;
    _plannedDate = task.plannedDate == null
        ? null
        : _dateOnly(task.plannedDate!);
    _deadlineDate = task.deadline == null ? null : _dateOnly(task.deadline!);
    _recurrence = task.recurrence;
    _customWeekdays = Set<int>.from(task.customWeekdays);
    _reminderMinutesBefore = task.reminderMinutesBefore;
    _enableLateReminder = task.lateReminderMinutesAfter != null;
    _lateReminderMinutes = task.lateReminderMinutesAfter ?? 30;
    _guardWarningSeconds = task.guardWarningSeconds;

    if (task.scheduledStart != null && task.scheduledEnd != null) {
      _scheduleOnCalendar = true;
      _scheduledDate = _dateOnly(task.scheduledStart!);
      _startTime = TimeOfDay.fromDateTime(task.scheduledStart!);
      _endTime = TimeOfDay.fromDateTime(task.scheduledEnd!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _navigateToPlanner() {
    if (context.mounted) {
      context.go('/?tab=planner&planner_area=tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_taskNotFound) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _navigateToPlanner)),
        body: const Center(child: Text('This task no longer exists.')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateToPlanner();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _navigateToPlanner),
          title: Text(
            widget.isEditing ? 'Edit Task' : 'New Task',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (widget.isEditing)
              IconButton(
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _isSaving ? null : _deleteTask,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            Text(
              widget.isEditing ? 'Update your task' : 'What needs to be done?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Task title'),
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add a description...',
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'Quicksand', fontSize: 14.5),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Priority'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PriorityButton(
                    label: 'Critical',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFFF6B5E),
                    selected: _priority == TaskPriority.critical,
                    onTap: () => setState(() {
                      _priority = TaskPriority.critical;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriorityButton(
                    label: 'Important',
                    icon: Icons.star_rounded,
                    color: AppTheme.primaryBlue,
                    selected: _priority == TaskPriority.important,
                    onTap: () => setState(() {
                      _priority = TaskPriority.important;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriorityButton(
                    label: 'Growth',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF34B27B),
                    selected: _priority == TaskPriority.growth,
                    onTap: () => setState(() {
                      _priority = TaskPriority.growth;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Planning'),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.event_note_outlined,
                  title: 'Plan for',
                  value: _plannedDate == null
                      ? 'Backlog'
                      : _dateLabel(_plannedDate!),
                  onTap: _showPlannedDateSheet,
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.flag_outlined,
                  title: 'Deadline',
                  value: _deadlineDate == null
                      ? 'None'
                      : _dateLabel(_deadlineDate!),
                  onTap: _showDeadlineSheet,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Calendar'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: _SettingSwitchRow(
                icon: Icons.calendar_month_rounded,
                title: 'Schedule task',
                subtitle: 'Set a time block, recurrence and optional reminder.',
                value: _scheduleOnCalendar,
                onChanged: (value) {
                  setState(() {
                    _scheduleOnCalendar = value;
                  });
                },
              ),
            ),
            if (_scheduleOnCalendar) ...[
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Date',
                    value: _dateLabel(_scheduledDate),
                    onTap: _pickScheduledDate,
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.schedule_outlined,
                    title: 'Start',
                    value: _startTime.format(context),
                    onTap: _pickStartTime,
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.timelapse_outlined,
                    title: 'End',
                    value: _endsNextDay
                        ? '${_endTime.format(context)} • next day'
                        : _endTime.format(context),
                    onTap: _pickEndTime,
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.repeat_rounded,
                    title: 'Repeat',
                    value: _recurrence.label,
                    onTap: _showRecurrencePicker,
                  ),
                  const Divider(height: 1),
                  _SettingRow(
                    icon: Icons.notifications_outlined,
                    title: 'Reminder',
                    value: _reminderLabel(_reminderMinutesBefore),
                    onTap: _showReminderPicker,
                  ),
                  const Divider(height: 1),
                  _SettingSwitchRow(
                    icon: Icons.alarm_off_outlined,
                    title: 'Late reminder if delayed',
                    subtitle: _enableLateReminder
                        ? 'Remind $_lateReminderMinutes min after scheduled time'
                        : 'No notification if overdue',
                    value: _enableLateReminder,
                    onChanged: (val) {
                      setState(() => _enableLateReminder = val);
                    },
                  ),
                  if (_enableLateReminder) ...[
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.timer_outlined,
                      title: 'Late delay',
                      value: '$_lateReminderMinutes min after',
                      onTap: _showLateDelayPicker,
                    ),
                  ],
                ],
              ),
              if (_recurrence == TaskRecurrence.customDays) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repeat on',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (
                            var weekday = DateTime.monday;
                            weekday <= DateTime.sunday;
                            weekday++
                          )
                            FilterChip(
                              label: Text(_weekdayLabel(weekday)),
                              selected: _customWeekdays.contains(weekday),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _customWeekdays.add(weekday);
                                  } else {
                                    _customWeekdays.remove(weekday);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            const _SectionTitle('Focus Guard Protection'),
            const SizedBox(height: 6),
            Text(
              'How long to wait after switching to a distracting app before alerting you.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.shield_outlined,
                  title: 'Distraction Warning Delay',
                  value: '$_guardWarningSeconds seconds',
                  onTap: _showGuardDelayPicker,
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveTask,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        widget.isEditing ? 'Update Task' : 'Create Task',
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _isSaving ? null : _deleteTask,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text(
                    'Delete Task',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask() async {
    final original = _originalTask;
    if (original == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          original.recurrence == TaskRecurrence.none
              ? 'Are you sure you want to delete "${original.title}"? This cannot be undone.'
              : 'Are you sure you want to delete the recurring task "${original.title}" and all its occurrences?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);
      try {
        await context.read<TaskProvider>().deleteTask(original.id);
        if (mounted) {
          _navigateToPlanner();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${original.title}"')),
          );
        }
      } catch (error) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showMessage('Could not delete task: $error');
        }
      }
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a task title.');
      return;
    }

    if (_scheduleOnCalendar &&
        _recurrence == TaskRecurrence.customDays &&
        _customWeekdays.isEmpty) {
      _showMessage('Choose at least one repeat day.');
      return;
    }

    DateTime? scheduledStart;
    DateTime? scheduledEnd;

    if (_scheduleOnCalendar) {
      scheduledStart = _combineDateAndTime(_scheduledDate, _startTime);

      if (_sameClockTime(_startTime, _endTime)) {
        _showMessage('Start and end time cannot be the same.');
        return;
      }

      final endDate = _endsNextDay
          ? DateTime(
              _scheduledDate.year,
              _scheduledDate.month,
              _scheduledDate.day + 1,
            )
          : _scheduledDate;

      scheduledEnd = _combineDateAndTime(endDate, _endTime);

      if (!scheduledEnd.isAfter(scheduledStart)) {
        _showMessage('End time must be after start time.');
        return;
      }
    }

    final taskProvider = context.read<TaskProvider>();

    if (scheduledStart != null && scheduledEnd != null) {
      final conflicts = taskProvider.findScheduleConflicts(
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        recurrence: _recurrence,
        customWeekdays: Set<int>.from(_customWeekdays),
        ignoreTaskId: widget.taskId,
      );

      if (conflicts.isNotEmpty) {
        await _showScheduleConflicts(conflicts);
        return;
      }
    }

    final deadline = _deadlineDate == null ? null : _endOfDay(_deadlineDate!);
    final recurrence = _scheduleOnCalendar ? _recurrence : TaskRecurrence.none;
    final customWeekdays = _scheduleOnCalendar
        ? Set<int>.from(_customWeekdays)
        : <int>{};
    final reminder = _scheduleOnCalendar ? _reminderMinutesBefore : null;
    final lateReminder = (_scheduleOnCalendar && _enableLateReminder)
        ? _lateReminderMinutes
        : null;

    setState(() {
      _isSaving = true;
    });

    try {
      late String savedTaskId;

      if (widget.isEditing) {
        final original = _originalTask;
        if (original == null) {
          throw StateError('Original task could not be loaded.');
        }

        final updatedTask = Task(
          id: original.id,
          title: title,
          description: _descriptionController.text.trim(),
          priority: _priority,
          plannedDate: _plannedDate,
          deadline: deadline,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          recurrence: recurrence,
          customWeekdays: customWeekdays,
          reminderMinutesBefore: reminder,
          lateReminderMinutesAfter: lateReminder,
          guardWarningSeconds: _guardWarningSeconds,
          isCompleted: original.isCompleted,
          createdAt: original.createdAt,
          completedAt: original.completedAt,
        );

        await taskProvider.updateTask(updatedTask);
        savedTaskId = updatedTask.id;
      } else {
        final createdTask = await taskProvider.createTask(
          title: title,
          description: _descriptionController.text.trim(),
          priority: _priority,
          plannedDate: _plannedDate,
          deadline: deadline,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          recurrence: recurrence,
          customWeekdays: customWeekdays,
          reminderMinutesBefore: reminder,
          lateReminderMinutesAfter: lateReminder,
          guardWarningSeconds: _guardWarningSeconds,
        );

        savedTaskId = createdTask.id;
      }

      if (!mounted) {
        return;
      }

      final reminderResult = taskProvider.lastReminderResult;

      if (reminder != null &&
          reminderResult != null &&
          reminderResult.taskId == savedTaskId &&
          reminderResult.requiresUserAttention) {
        await _showReminderResult(reminderResult);
      }

      if (!mounted) {
        return;
      }

      if (mounted) {
        _navigateToPlanner();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEditing
            ? 'Could not update the task. Please try again.'
            : 'Could not save the task. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showScheduleConflicts(
    List<TaskScheduleConflict> conflicts,
  ) async {
    final visible = conflicts.take(4).toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Schedule conflict'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This time overlaps with an existing scheduled task. Choose another time before saving.',
              ),
              const SizedBox(height: 14),
              ...visible.map(
                (conflict) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${conflict.task.title}\n'
                          '${DateFormat('EEE, d MMM • h:mm a').format(conflict.existingStart)}'
                          ' – ${DateFormat('h:mm a').format(conflict.existingEnd)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (conflicts.length > visible.length)
                Text('+${conflicts.length - visible.length} more conflict(s)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Change time'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReminderResult(TaskReminderScheduleResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Task saved — reminder needs attention'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPlannedDateSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Plan task for',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('Today'),
                onTap: () {
                  setState(() {
                    _plannedDate = _dateOnly(DateTime.now());
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Tomorrow'),
                onTap: () {
                  setState(() {
                    _plannedDate = _dateOnly(
                      DateTime.now().add(const Duration(days: 1)),
                    );
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Choose date'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickPlannedDate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Backlog / No date'),
                onTap: () {
                  setState(() {
                    _plannedDate = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPlannedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _plannedDate = _dateOnly(picked);
    });
  }

  void _showDeadlineSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Deadline',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('Today'),
                onTap: () {
                  setState(() {
                    _deadlineDate = _dateOnly(DateTime.now());
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Tomorrow'),
                onTap: () {
                  setState(() {
                    _deadlineDate = _dateOnly(
                      DateTime.now().add(const Duration(days: 1)),
                    );
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Choose date'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickDeadlineDate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('No deadline'),
                onTap: () {
                  setState(() {
                    _deadlineDate = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? _plannedDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _deadlineDate = _dateOnly(picked);
    });
  }

  Future<void> _pickScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _scheduledDate = _dateOnly(picked);
      _plannedDate = _scheduledDate;
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _startTime = picked;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _endTime = picked;
    });
  }

  void _showRecurrencePicker() {
    _showSimpleOptions<TaskRecurrence>(
      title: 'Repeat',
      values: TaskRecurrence.values,
      label: (value) => value.label,
      onSelected: (value) {
        setState(() {
          _recurrence = value;
          if (value != TaskRecurrence.customDays) {
            _customWeekdays.clear();
          }
        });
      },
    );
  }

  void _showReminderPicker() {
    final values = <int?>[null, 0, 5, 10, 15, 30, 60];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                ListTile(
                  title: Text(
                    'Reminder',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...values.map(
                  (value) => ListTile(
                    title: Text(
                      _reminderLabel(value),
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    trailing: value == _reminderMinutesBefore
                        ? Icon(Icons.check_rounded, color: scheme.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _reminderMinutesBefore = value;
                      });
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGuardDelayPicker() {
    final options = [10, 15, 30, 45, 60, 120];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                title: Text(
                  'Distraction Warning Delay',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'How long before Focus Guard warns you when using distracting apps.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ...options.map(
                (sec) => ListTile(
                  title: Text(
                    '$sec seconds${sec == 30 ? ' (Recommended)' : ''}',
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  trailing: sec == _guardWarningSeconds
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _guardWarningSeconds = sec;
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLateDelayPicker() {
    final options = [15, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                title: Text(
                  'Late reminder delay',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'How long after the task end to notify you if incomplete.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ...options.map(
                (mins) => ListTile(
                  title: Text(
                    '$mins minutes after',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: mins == _lateReminderMinutes
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: mins == _lateReminderMinutes
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _lateReminderMinutes = mins;
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSimpleOptions<T>({
    required String title,
    required List<T> values,
    required String Function(T value) label,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                ListTile(
                  title: Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...values.map(
                  (value) => ListTile(
                    title: Text(
                      label(value),
                      style: TextStyle(color: scheme.onSurface),
                    ),
                    onTap: () {
                      onSelected(value);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _reminderLabel(int? minutes) {
    if (minutes == null) {
      return 'None';
    }
    if (minutes == 0) {
      return 'At start time';
    }
    if (minutes == 60) {
      return '1 hour before';
    }
    return '$minutes min before';
  }

  String _weekdayLabel(int weekday) {
    const labels = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    return labels[weekday]!;
  }

  String _dateLabel(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final cleanDate = _dateOnly(date);

    if (cleanDate == today) {
      return 'Today';
    }
    if (cleanDate == tomorrow) {
      return 'Tomorrow';
    }

    return DateFormat('EEE, d MMM').format(date);
  }

  bool get _endsNextDay {
    return _minutesOfDay(_endTime) < _minutesOfDay(_startTime);
  }

  bool _sameClockTime(TimeOfDay first, TimeOfDay second) {
    return _minutesOfDay(first) == _minutesOfDay(second);
  }

  int _minutesOfDay(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : color.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    color: selected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  (value
                          ? AppTheme.primaryBlue
                          : theme.colorScheme.outlineVariant)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: value
                  ? AppTheme.primaryBlue
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryBlue,
            activeTrackColor: AppTheme.primaryBlue.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

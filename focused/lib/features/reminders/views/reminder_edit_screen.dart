import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../tasks/models/task.dart';
import '../../tasks/models/task_recurrence.dart';
import '../../tasks/providers/task_provider.dart';

class ReminderEditScreen extends StatefulWidget {
  final String? reminderId;

  const ReminderEditScreen({super.key, this.reminderId});

  bool get isEditing => reminderId != null;

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late DateTime _scheduledDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);

  TaskRecurrence _recurrence = TaskRecurrence.none;
  Set<int> _customWeekdays = <int>{};
  int _reminderMinutesBefore = 0; // At time of event
  bool _enableLateReminder = false;
  int _lateReminderMinutes = 30;

  bool _isSaving = false;
  bool _didLoadExisting = false;
  bool _notFound = false;
  Task? _originalTask;

  @override
  void initState() {
    super.initState();
    _scheduledDate = _dateOnly(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadExisting) return;
    _didLoadExisting = true;

    final id = widget.reminderId;
    if (id == null) return;

    final task = context.read<TaskProvider>().getTaskById(id);
    if (task == null) {
      _notFound = true;
      return;
    }

    _originalTask = task;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _recurrence = task.recurrence;
    _customWeekdays = Set<int>.from(task.customWeekdays);
    _reminderMinutesBefore = task.reminderMinutesBefore ?? 0;
    _enableLateReminder = task.lateReminderMinutesAfter != null;
    _lateReminderMinutes = task.lateReminderMinutesAfter ?? 30;

    if (task.scheduledStart != null) {
      _scheduledDate = _dateOnly(task.scheduledStart!);
      _startTime = TimeOfDay.fromDateTime(task.scheduledStart!);
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
      context.go('/?tab=planner&planner_area=reminders');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _navigateToPlanner)),
        body: const Center(child: Text('This reminder no longer exists.')),
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
            widget.isEditing ? 'Edit Reminder' : 'New Reminder',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (widget.isEditing)
              IconButton(
                tooltip: 'Delete reminder',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _isSaving ? null : _deleteReminder,
              ),
            TextButton(
              onPressed: _isSaving ? null : _saveReminder,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            Text(
              widget.isEditing ? 'Update your reminder' : 'Set a reminder',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Reminder title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Schedule & Timing'),
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
                  title: 'Time',
                  value: _startTime.format(context),
                  onTap: _pickStartTime,
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
                  icon: Icons.notifications_active_outlined,
                  title: 'Alarm alert',
                  value: _reminderLabel(_reminderMinutesBefore),
                  onTap: _showReminderPicker,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.alarm_off_outlined),
                  title: const Text(
                    'Late reminder if delayed',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    _enableLateReminder
                        ? 'Remind $_lateReminderMinutes min after scheduled time'
                        : 'No notification if overdue',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
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
            const SizedBox(height: 32),
            SizedBox(
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9600),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _saveReminder,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEditing
                            ? 'Update Reminder'
                            : 'Create Reminder',
                        style: const TextStyle(
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
                  onPressed: _isSaving ? null : _deleteReminder,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text(
                    'Delete Reminder',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteReminder() async {
    final original = _originalTask;
    if (original == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(
          'Are you sure you want to delete "${original.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
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
          _showMessage('Could not delete reminder: $error');
        }
      }
    }
  }

  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Please enter a reminder title.');
      return;
    }

    if (_recurrence == TaskRecurrence.customDays && _customWeekdays.isEmpty) {
      _showMessage('Choose at least one repeat day.');
      return;
    }

    final scheduledStart = _combineDateAndTime(_scheduledDate, _startTime);
    final scheduledEnd = scheduledStart.add(const Duration(minutes: 30));

    final provider = context.read<TaskProvider>();
    final original = _originalTask;

    final reminderTask = Task(
      id: original?.id ?? 'rem_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descriptionController.text.trim(),
      priority: original?.priority ?? TaskPriority.growth,
      plannedDate: _scheduledDate,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recurrence: _recurrence,
      customWeekdays: _customWeekdays,
      reminderMinutesBefore: _reminderMinutesBefore,
      lateReminderMinutesAfter: _enableLateReminder
          ? _lateReminderMinutes
          : null,
      createdAt: original?.createdAt ?? DateTime.now(),
      isCompleted: original?.isCompleted ?? false,
      completedAt: original?.completedAt,
      isReminder: true,
    );

    setState(() => _isSaving = true);

    try {
      if (widget.isEditing) {
        await provider.updateTask(reminderTask);
      } else {
        await provider.addTask(reminderTask);
      }

      if (mounted) {
        _navigateToPlanner();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage('Could not save reminder: $error');
      }
    }
  }

  Future<void> _pickScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _scheduledDate = _dateOnly(picked);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _showRecurrencePicker() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskRecurrence.values.map((item) {
            return ListTile(
              title: Text(item.label),
              trailing: _recurrence == item
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                setState(() => _recurrence = item);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showReminderPicker() {
    const options = [
      MapEntry(0, 'At time of event'),
      MapEntry(5, '5 minutes before'),
      MapEntry(10, '10 minutes before'),
      MapEntry(15, '15 minutes before'),
      MapEntry(30, '30 minutes before'),
      MapEntry(60, '1 hour before'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((entry) {
            return ListTile(
              title: Text(entry.value),
              trailing: _reminderMinutesBefore == entry.key
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                setState(() => _reminderMinutesBefore = entry.key);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLateDelayPicker() {
    final options = [15, 20, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Late reminder delay',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...options.map((mins) {
              return ListTile(
                title: Text('$mins minutes after'),
                trailing: _lateReminderMinutes == mins
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  setState(() => _lateReminderMinutes = mins);
                  Navigator.pop(sheetContext);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _combineDateAndTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  static String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final target = _dateOnly(date);

    if (target == today) return 'Today';
    if (target == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  static String _reminderLabel(int minutes) {
    if (minutes == 0) return 'At event time';
    if (minutes < 60) return '$minutes min before';
    return '${minutes ~/ 60}h before';
  }

  static String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF9600)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  TaskPriority _priority = TaskPriority.important;

  int _estimatedMinutes = 60;

  late DateTime _plannedDate;

  DateTime? _deadlineDate;

  bool _scheduleOnCalendar = false;

  late DateTime _scheduledDate;

  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);

  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final today = _dateOnly(DateTime.now());

    _plannedDate = today;

    // Keep your previous UI behaviour:
    // deadline defaults to today.
    _deadlineDate = today;

    _scheduledDate = today;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveTask,
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
            'What needs to be done?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 18),

          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Task title'),
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

          const SizedBox(height: 28),

          const _SectionTitle('Priority'),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _PriorityButton(
                  label: 'Critical',
                  color: const Color(0xFFFF6B5E),
                  selected: _priority == TaskPriority.critical,
                  onTap: () {
                    setState(() {
                      _priority = TaskPriority.critical;
                    });
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _PriorityButton(
                  label: 'Important',
                  color: AppTheme.primaryBlue,
                  selected: _priority == TaskPriority.important,
                  onTap: () {
                    setState(() {
                      _priority = TaskPriority.important;
                    });
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _PriorityButton(
                  label: 'Growth',
                  color: const Color(0xFF34B27B),
                  selected: _priority == TaskPriority.growth,
                  onTap: () {
                    setState(() {
                      _priority = TaskPriority.growth;
                    });
                  },
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
                icon: Icons.timer_outlined,
                title: 'Estimated duration',
                value: _durationLabel(_estimatedMinutes),
                onTap: _showDurationPicker,
              ),

              const Divider(height: 1),

              _SettingRow(
                icon: Icons.event_note_outlined,
                title: 'Plan for',
                value: _dateLabel(_plannedDate),
                onTap: _pickPlannedDate,
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

          const SizedBox(height: 22),

          const _SectionTitle('Calendar'),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              value: _scheduleOnCalendar,
              onChanged: (value) {
                setState(() {
                  _scheduleOnCalendar = value;
                });
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: const Text(
                'Schedule task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Set a time block now. Google sync will be added later.',
                ),
              ),
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
                  value: _endTime.format(context),
                  onTap: _pickEndTime,
                ),
              ],
            ),
          ],

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
                  : const Text(
                      'Create Task',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SAVE TASK
  // =========================================================

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a task title.');

      return;
    }

    DateTime? scheduledStart;
    DateTime? scheduledEnd;

    if (_scheduleOnCalendar) {
      scheduledStart = _combineDateAndTime(_scheduledDate, _startTime);

      scheduledEnd = _combineDateAndTime(_scheduledDate, _endTime);

      if (!scheduledEnd.isAfter(scheduledStart)) {
        _showMessage('End time must be after start time.');

        return;
      }
    }

    // A deadline selected as "August 30"
    // should mean the END of August 30,
    // not 12:00 AM at the beginning of the day.
    final deadline = _deadlineDate == null ? null : _endOfDay(_deadlineDate!);

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<TaskProvider>().createTask(
        title: title,
        description: _descriptionController.text.trim(),
        priority: _priority,
        estimatedMinutes: _estimatedMinutes,
        plannedDate: _plannedDate,
        deadline: deadline,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not save the task. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // DURATION
  // =========================================================

  String _durationLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '${hours}h ${remaining}m';
  }

  void _showDurationPicker() {
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
                  'Estimated duration',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 16),

                _DurationChoice(label: '30 min', onTap: () => _setDuration(30)),

                _DurationChoice(label: '45 min', onTap: () => _setDuration(45)),

                _DurationChoice(label: '1 hour', onTap: () => _setDuration(60)),

                _DurationChoice(
                  label: '1 hour 30 min',
                  onTap: () => _setDuration(90),
                ),

                _DurationChoice(
                  label: '2 hours',
                  onTap: () => _setDuration(120),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setDuration(int value) {
    setState(() {
      _estimatedMinutes = value;
    });

    Navigator.pop(context);
  }

  // =========================================================
  // PLANNED DATE
  // =========================================================

  Future<void> _pickPlannedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
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

  // =========================================================
  // DEADLINE
  // =========================================================

  void _showDeadlineSheet() {
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
                  'Deadline',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 16),

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
          ),
        );
      },
    );
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? _plannedDate,
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

  // =========================================================
  // SCHEDULE
  // =========================================================

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

      // If the user schedules the task,
      // it makes sense for that day to
      // also become its planned day.
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

  // =========================================================
  // HELPERS
  // =========================================================

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
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : null,
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
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

class _DurationChoice extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DurationChoice({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/task_recurrence.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

class TaskDetailsScreen extends StatelessWidget {
  final String taskId;
  final DateTime? occurrenceDate;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    this.occurrenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final focus = context.watch<FocusProvider>();
    final task = tasks.getTaskById(taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found.')),
      );
    }

    final day = _dateOnly(
      occurrenceDate ?? task.plannedDate ?? task.scheduledStart ?? DateTime.now(),
    );
    final occurrence = tasks.occurrenceForTaskOnDate(task, day);
    final completed = tasks.isTaskCompletedForDate(task, day);

    final linkedSessions = focus.sessionHistory.where((session) {
      if (session.taskId != task.id) return false;
      if (task.recurrence == TaskRecurrence.none) return true;
      final linkedDay = session.linkedOccurrenceDate;
      return linkedDay != null && _sameDate(linkedDay, day);
    }).toList();

    final focused = linkedSessions.fold<Duration>(
      Duration.zero,
      (total, session) => total + session.actualFocusDuration,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          TextButton(
            onPressed: () => context.push(
              '/task/edit/${Uri.encodeComponent(task.id)}',
            ),
            child: const Text('Edit'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          _TaskHeader(
            task: task,
            completed: completed,
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              task.description.trim(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          _DetailsCard(
            task: task,
            day: day,
            occurrenceStart: occurrence?.start,
            occurrenceEnd: occurrence?.end,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: _formatDuration(focused),
                  label: 'Focused',
                  icon: Icons.center_focus_strong_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: '${linkedSessions.length}',
                  label: linkedSessions.length == 1 ? 'Session' : 'Sessions',
                  icon: Icons.history_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!completed)
            FilledButton.icon(
              onPressed: () => context.push(
                '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}&occurrenceDate=${_dateQuery(day)}',
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start focus'),
            ),
          if (!completed) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => tasks.setCompletedForDate(
              task.id,
              day,
              !completed,
              completedAt: completed ? null : DateTime.now(),
            ),
            icon: Icon(
              completed ? Icons.undo_rounded : Icons.check_rounded,
            ),
            label: Text(completed ? 'Mark incomplete' : 'Mark complete'),
          ),
        ],
      ),
    );
  }
}

class _TaskHeader extends StatelessWidget {
  final Task task;
  final bool completed;

  const _TaskHeader({
    required this.task,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            completed ? Icons.check_rounded : Icons.task_alt_rounded,
            color: color,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.priority.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (completed) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Task task;
  final DateTime day;
  final DateTime? occurrenceStart;
  final DateTime? occurrenceEnd;

  const _DetailsCard({
    required this.task,
    required this.day,
    required this.occurrenceStart,
    required this.occurrenceEnd,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_DetailRow>[
      _DetailRow(
        icon: Icons.calendar_today_outlined,
        label: 'Date',
        value: DateFormat('EEEE, MMM d').format(day),
      ),
      if (occurrenceStart != null && occurrenceEnd != null)
        _DetailRow(
          icon: Icons.schedule_rounded,
          label: 'Time',
          value:
              '${DateFormat('h:mm a').format(occurrenceStart!)} – ${DateFormat('h:mm a').format(occurrenceEnd!)}',
        ),
      if (task.recurrence != TaskRecurrence.none)
        _DetailRow(
          icon: Icons.repeat_rounded,
          label: 'Repeats',
          value: _recurrenceLabel(task),
        ),
      if (task.reminderMinutesBefore != null)
        _DetailRow(
          icon: Icons.notifications_none_rounded,
          label: 'Reminder',
          value: task.reminderMinutesBefore == 0
              ? 'At start time'
              : '${task.reminderMinutesBefore} min before',
        ),
      if (task.deadline != null)
        _DetailRow(
          icon: Icons.flag_outlined,
          label: 'Deadline',
          value: DateFormat('MMM d, h:mm a').format(task.deadline!),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          return Column(
            children: [
              ListTile(
                leading: Icon(row.icon),
                title: Text(row.label),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    row.value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (index != rows.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

String _recurrenceLabel(Task task) {
  switch (task.recurrence) {
    case TaskRecurrence.none:
      return 'Does not repeat';
    case TaskRecurrence.daily:
      return 'Every day';
    case TaskRecurrence.weekdays:
      return 'Weekdays';
    case TaskRecurrence.weekly:
      return 'Every week';
    case TaskRecurrence.customDays:
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final days = task.customWeekdays.toList()..sort();
      return days.map((day) => names[day - 1]).join(', ');
  }
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return AppTheme.danger;
    case TaskPriority.important:
      return AppTheme.primaryBlue;
    case TaskPriority.growth:
      return AppTheme.success;
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

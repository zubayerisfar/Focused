import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/task_recurrence.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

enum _PlannerView { today, upcoming, backlog, completed }

enum _TaskMenuAction { edit, reschedule, delete }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  _PlannerView _selectedView = _PlannerView.today;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    final now = DateTime.now();

    final todayTasks = taskProvider.plannerToday(now: now);

    final upcomingTasks = taskProvider.plannerUpcoming(now: now);

    final backlogTasks = taskProvider.plannerBacklog(now: now);

    final completedTasks = taskProvider.plannerCompleted();

    final visibleTasks = switch (_selectedView) {
      _PlannerView.today => todayTasks,
      _PlannerView.upcoming => upcomingTasks,
      _PlannerView.backlog => backlogTasks,
      _PlannerView.completed => completedTasks,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _PlannerSummary(
            openCount: taskProvider.incompleteTasks.length,
            completedCount: completedTasks.length,
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _PlannerChip(
                  label: 'Today',
                  count: todayTasks.length,
                  selected: _selectedView == _PlannerView.today,
                  onTap: () {
                    setState(() {
                      _selectedView = _PlannerView.today;
                    });
                  },
                ),

                const SizedBox(width: 8),

                _PlannerChip(
                  label: 'Upcoming',
                  count: upcomingTasks.length,
                  selected: _selectedView == _PlannerView.upcoming,
                  onTap: () {
                    setState(() {
                      _selectedView = _PlannerView.upcoming;
                    });
                  },
                ),

                const SizedBox(width: 8),

                _PlannerChip(
                  label: 'Backlog',
                  count: backlogTasks.length,
                  selected: _selectedView == _PlannerView.backlog,
                  onTap: () {
                    setState(() {
                      _selectedView = _PlannerView.backlog;
                    });
                  },
                ),

                const SizedBox(width: 8),

                _PlannerChip(
                  label: 'Completed',
                  count: completedTasks.length,
                  selected: _selectedView == _PlannerView.completed,
                  onTap: () {
                    setState(() {
                      _selectedView = _PlannerView.completed;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: visibleTasks.isEmpty
              ? _PlannerEmptyState(view: _selectedView)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: visibleTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];

                    return _PlannerTaskCard(
                      task: task,
                      now: now,
                      onToggleComplete: () => _toggleTask(task),
                      onStartFocus: task.isCompleted
                          ? null
                          : () {
                              context.push(
                                '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                              );
                            },
                      onMenuAction: (action) {
                        switch (action) {
                          case _TaskMenuAction.edit:
                            context.push(
                              '/task/edit/${Uri.encodeComponent(task.id)}',
                            );

                          case _TaskMenuAction.reschedule:
                            _rescheduleTask(task);

                          case _TaskMenuAction.delete:
                            _confirmDelete(task);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _toggleTask(Task task) async {
    try {
      await context.read<TaskProvider>().setCompleted(
        task.id,
        !task.isCompleted,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not update the task.');
    }
  }

  Future<void> _rescheduleTask(Task task) async {
    final initialDate =
        task.scheduledStart ?? task.plannedDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked == null || !mounted) {
      return;
    }

    DateTime? newScheduledStart;
    DateTime? newScheduledEnd;

    if (task.scheduledStart != null && task.scheduledEnd != null) {
      final oldStart = task.scheduledStart!;

      final oldDuration = task.scheduledEnd!.difference(oldStart);

      newScheduledStart = DateTime(
        picked.year,
        picked.month,
        picked.day,
        oldStart.hour,
        oldStart.minute,
        oldStart.second,
      );

      newScheduledEnd = newScheduledStart.add(oldDuration);
    }

    final updated = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      priority: task.priority,
      estimatedMinutes: task.estimatedMinutes,
      plannedDate: DateTime(picked.year, picked.month, picked.day),
      deadline: task.deadline,
      scheduledStart: newScheduledStart,
      scheduledEnd: newScheduledEnd,
      recurrence: task.recurrence,
      customWeekdays: Set<int>.from(task.customWeekdays),
      reminderMinutesBefore: task.reminderMinutesBefore,
      isCompleted: task.isCompleted,
      createdAt: task.createdAt,
      completedAt: task.completedAt,
    );

    try {
      await context.read<TaskProvider>().updateTask(updated);

      if (!mounted) {
        return;
      }

      _showMessage('Task moved to ${DateFormat('EEE, d MMM').format(picked)}.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not reschedule the task.');
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('"${task.title}" will be permanently removed.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<TaskProvider>().deleteTask(task.id);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not delete the task.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PlannerSummary extends StatelessWidget {
  final int openCount;
  final int completedCount;

  const _PlannerSummary({
    required this.openCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              icon: Icons.task_alt_rounded,
              value: '$openCount',
              label: 'Open tasks',
              color: AppTheme.primaryBlue,
            ),
          ),

          Container(
            width: 1,
            height: 48,
            color: Theme.of(context).dividerColor.withOpacity(0.25),
          ),

          Expanded(
            child: _SummaryValue(
              icon: Icons.check_circle_rounded,
              value: '$completedCount',
              label: 'Completed',
              color: const Color(0xFF34B27B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryValue({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),

            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.50),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlannerChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlannerChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text('$label  $count'),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _PlannerTaskCard extends StatelessWidget {
  final Task task;
  final DateTime now;

  final VoidCallback onToggleComplete;

  final VoidCallback? onStartFocus;

  final ValueChanged<_TaskMenuAction> onMenuAction;

  const _PlannerTaskCard({
    required this.task,
    required this.now,
    required this.onToggleComplete,
    required this.onStartFocus,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);

    final overdue = _taskIsOverdue(task, now);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onToggleComplete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        task.priority.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),

                    if (overdue && !task.isCompleted) ...[
                      const SizedBox(width: 7),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'OVERDUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 9),

                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),

                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),

                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.50),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Wrap(spacing: 10, runSpacing: 7, children: _taskMeta(task)),

                if (!task.isCompleted) ...[
                  const SizedBox(height: 13),

                  OutlinedButton.icon(
                    onPressed: onStartFocus,
                    icon: const Icon(Icons.play_arrow_rounded, size: 19),
                    label: const Text('Start Focus'),
                  ),
                ],
              ],
            ),
          ),

          PopupMenuButton<_TaskMenuAction>(
            onSelected: onMenuAction,
            itemBuilder: (_) {
              return [
                const PopupMenuItem(
                  value: _TaskMenuAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),

                if (!task.isCompleted)
                  const PopupMenuItem(
                    value: _TaskMenuAction.reschedule,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_repeat_rounded),
                      title: Text('Reschedule'),
                    ),
                  ),

                const PopupMenuItem(
                  value: _TaskMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _PlannerEmptyState extends StatelessWidget {
  final _PlannerView view;

  const _PlannerEmptyState({required this.view});

  @override
  Widget build(BuildContext context) {
    final title = switch (view) {
      _PlannerView.today => 'Nothing demanding your attention',
      _PlannerView.upcoming => 'No upcoming tasks',
      _PlannerView.backlog => 'Your backlog is clear',
      _PlannerView.completed => 'No completed tasks yet',
    };

    final subtitle = switch (view) {
      _PlannerView.today =>
        'Create a task or enjoy the free space in your day.',
      _PlannerView.upcoming =>
        'Future planned and scheduled tasks will appear here.',
      _PlannerView.backlog => 'Tasks without a planned date will appear here.',
      _PlannerView.completed => 'Completed work will build your history here.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 52,
              color: AppTheme.primaryBlue,
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.50),
              ),
            ),

            if (view != _PlannerView.completed) ...[
              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: () {
                  context.push('/task/new');
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<Widget> _taskMeta(Task task) {
  final items = <Widget>[];

  items.add(
    _MetaItem(
      icon: Icons.timer_outlined,
      text: _durationText(task.estimatedMinutes),
    ),
  );

  if (task.scheduledStart != null) {
    items.add(
      _MetaItem(
        icon: Icons.schedule_rounded,
        text: DateFormat('EEE, d MMM • h:mm a').format(task.scheduledStart!),
      ),
    );
  } else if (task.plannedDate != null) {
    items.add(
      _MetaItem(
        icon: Icons.event_note_outlined,
        text: DateFormat('EEE, d MMM').format(task.plannedDate!),
      ),
    );
  }

  if (task.deadline != null) {
    items.add(
      _MetaItem(
        icon: Icons.flag_outlined,
        text: 'Due ${DateFormat('d MMM').format(task.deadline!)}',
      ),
    );
  }

  if (task.isCompleted && task.completedAt != null) {
    items.add(
      _MetaItem(
        icon: Icons.check_circle_outline,
        text: 'Done ${DateFormat('d MMM').format(task.completedAt!)}',
      ),
    );
  }

  return items;
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        ),

        const SizedBox(width: 4),

        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.50),
          ),
        ),
      ],
    );
  }
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.critical:
      return const Color(0xFFFF6B5E);

    case TaskPriority.important:
      return AppTheme.primaryBlue;

    case TaskPriority.growth:
      return const Color(0xFF34B27B);
  }
}

String _durationText(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }

  final hours = minutes ~/ 60;

  final remaining = minutes % 60;

  if (remaining == 0) {
    return '${hours}h';
  }

  return '${hours}h ${remaining}m';
}

bool _taskIsOverdue(Task task, DateTime now) {
  if (task.isCompleted || task.recurrence != TaskRecurrence.none) {
    return false;
  }

  if (task.deadline != null && task.deadline!.isBefore(now)) {
    return true;
  }

  if (task.scheduledEnd != null && task.scheduledEnd!.isBefore(now)) {
    return true;
  }

  if (task.plannedDate != null) {
    final planned = DateTime(
      task.plannedDate!.year,
      task.plannedDate!.month,
      task.plannedDate!.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    if (planned.isBefore(today)) {
      return true;
    }
  }

  return false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../models/task_recurrence.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
  });

  @override
  State<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState
    extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = context
        .watch<TaskProvider>()
        .scheduledOccurrencesForDate(
          _selectedDate,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        120,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surface,
            borderRadius:
                BorderRadius.circular(22),
          ),
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(
              DateTime.now().year - 2,
            ),
            lastDate: DateTime(
              DateTime.now().year + 10,
            ),
            onDateChanged: (date) {
              setState(() {
                _selectedDate =
                    DateTime(
                  date.year,
                  date.month,
                  date.day,
                );
              });
            },
          ),
        ),

        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: Text(
                _dayLabel(_selectedDate),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                context.push('/task/new');
              },
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text('Task'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (occurrences.isEmpty)
          const _EmptySchedule()
        else
          ...occurrences.map(
            (occurrence) =>
                _OccurrenceCard(
              occurrence:
                  occurrence,
            ),
          ),
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();

    if (_sameDate(date, today)) {
      return 'Today';
    }

    return DateFormat(
      'EEEE, d MMMM',
    ).format(date);
  }
}

class _OccurrenceCard extends StatelessWidget {
  final TaskOccurrence occurrence;

  const _OccurrenceCard({
    required this.occurrence,
  });

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final today = DateTime.now();
    final occurrenceDay = DateTime(
      occurrence.start.year,
      occurrence.start.month,
      occurrence.start.day,
    );
    final todayDay = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final canToggleComplete =
        task.recurrence == TaskRecurrence.none ||
        !occurrenceDay.isAfter(todayDay);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: canToggleComplete
                ? () async {
                    try {
                      await context.read<TaskProvider>().setCompletedForDate(
                            task.id,
                            occurrence.start,
                            !occurrence.isCompleted,
                          );
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not update the task.'),
                        ),
                      );
                    }
                  }
                : null,
            child: Opacity(
              opacity: canToggleComplete ? 1 : 0.35,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: occurrence.isCompleted
                      ? color
                      : Colors.transparent,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: occurrence.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('h:mm a').format(occurrence.start),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: occurrence.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('h:mm a').format(occurrence.end),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: occurrence.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.recurrence.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.50),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: occurrence.isCompleted
                          ? null
                          : () {
                              context.push(
                                '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                              );
                            },
                      icon: Icon(
                        occurrence.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(
                        occurrence.isCompleted
                            ? 'Completed'
                            : 'Focus',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.push(
                          '/task/edit/${Uri.encodeComponent(task.id)}',
                        );
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule
    extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 40,
            color:
                AppTheme.primaryBlue,
          ),
          SizedBox(height: 10),
          Text(
            'No scheduled tasks',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Color _priorityColor(
  TaskPriority priority,
) {
  switch (priority) {
    case TaskPriority.critical:
      return const Color(
        0xFFFF6B5E,
      );

    case TaskPriority.important:
      return AppTheme.primaryBlue;

    case TaskPriority.growth:
      return const Color(
        0xFF34B27B,
      );
  }
}

bool _sameDate(
  DateTime first,
  DateTime second,
) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

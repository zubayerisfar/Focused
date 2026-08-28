import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/habit.dart';
import '../../models/task.dart';
import '../../models/task_occurrence.dart';
import '../../models/task_recurrence.dart';
import '../../providers/habit_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

enum PlannerCalendarMode {
  schedule,
  day,
  threeDays,
  week,
  month,
}

extension PlannerCalendarModeLabel on PlannerCalendarMode {
  String get label {
    switch (this) {
      case PlannerCalendarMode.schedule:
        return 'Schedule';
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

enum _PlannerArea { tasks, habits }

enum _PlannerMenuAction { backlog, completed, settings }

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  _PlannerArea _area = _PlannerArea.tasks;
  PlannerCalendarMode _calendarMode = PlannerCalendarMode.schedule;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              _PlannerHeader(
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
                onMenuAction: _handleMenuAction,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_PlannerArea>(
                    segments: const [
                      ButtonSegment(
                        value: _PlannerArea.tasks,
                        icon: Icon(Icons.checklist_rounded),
                        label: Text('Tasks'),
                      ),
                      ButtonSegment(
                        value: _PlannerArea.habits,
                        icon: Icon(Icons.repeat_rounded),
                        label: Text('Habits'),
                      ),
                    ],
                    selected: {_area},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() {
                        _area = selection.first;
                      });
                    },
                  ),
                ),
              ),
              Expanded(
                child: _area == _PlannerArea.tasks
                    ? _TaskCalendarBody(
                        mode: _calendarMode,
                        selectedDate: _selectedDate,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = _dateOnly(date);
                          });
                        },
                      )
                    : _HabitPlannerBody(
                        selectedDate: _selectedDate,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = _dateOnly(date);
                          });
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              heroTag: 'planner-create',
              onPressed: () => context.push(
                _area == _PlannerArea.tasks ? '/task/new' : '/habit/new',
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _area == _PlannerArea.tasks ? 'New task' : 'New habit',
              ),
            ),
          ),
        ],
      ),
    );
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

  void _handleMenuAction(_PlannerMenuAction action) {
    switch (action) {
      case _PlannerMenuAction.backlog:
        _showTaskCollectionSheet(
          context,
          title: 'Backlog',
          tasks: context.read<TaskProvider>().plannerBacklog(),
        );
        return;
      case _PlannerMenuAction.completed:
        _showCompletedSheet(context);
        return;
      case _PlannerMenuAction.settings:
        context.push('/settings');
        return;
    }
  }
}

class _PlannerHeader extends StatelessWidget {
  final DateTime selectedDate;
  final _PlannerArea area;
  final PlannerCalendarMode calendarMode;
  final VoidCallback onPickDate;
  final VoidCallback onToday;
  final ValueChanged<PlannerCalendarMode> onModeChanged;
  final ValueChanged<_PlannerMenuAction> onMenuAction;

  const _PlannerHeader({
    required this.selectedDate,
    required this.area,
    required this.calendarMode,
    required this.onPickDate,
    required this.onToday,
    required this.onModeChanged,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onPickDate,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('MMMM yyyy').format(selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
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
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (area == _PlannerArea.tasks)
            PopupMenuButton<PlannerCalendarMode>(
              tooltip: 'Change calendar view',
              initialValue: calendarMode,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
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
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              icon: const Icon(Icons.view_week_outlined, size: 22),
            ),
          PopupMenuButton<_PlannerMenuAction>(
            tooltip: 'More',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            onSelected: onMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PlannerMenuAction.backlog,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Backlog'),
                ),
              ),
              PopupMenuItem(
                value: _PlannerMenuAction.completed,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.done_all_rounded),
                  title: Text('Completed'),
                ),
              ),
              PopupMenuItem(
                value: _PlannerMenuAction.settings,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
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
  final VoidCallback onPressed;
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
      constraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 40,
      ),
      icon: child,
    );
  }
}

class _TaskCalendarBody extends StatelessWidget {
  final PlannerCalendarMode mode;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _TaskCalendarBody({
    required this.mode,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case PlannerCalendarMode.schedule:
        return _ScheduleView(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        );
      case PlannerCalendarMode.day:
        return _DayView(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        );
      case PlannerCalendarMode.threeDays:
        return _MultiDayFlow(
          selectedDate: selectedDate,
          dayCount: 3,
          onDateSelected: onDateSelected,
        );
      case PlannerCalendarMode.week:
        return _MultiDayFlow(
          selectedDate: _weekStart(selectedDate),
          dayCount: 7,
          onDateSelected: onDateSelected,
        );
      case PlannerCalendarMode.month:
        return _MonthView(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        );
    }
  }
}

class _ScheduleView extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _ScheduleView({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final days = List<DateTime>.generate(
      7,
      (index) => selectedDate.add(Duration(days: index)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _CalendarModeIntro(
          title: 'Schedule',
          subtitle: 'Your next seven days in one continuous flow.',
          selectedDate: selectedDate,
        ),
        const SizedBox(height: 18),
        ...days.map((date) {
          final occurrences = provider.scheduledOccurrencesForDate(date);
          final anytime = provider
              .tasksForDate(date, includeCompleted: true)
              .where((task) => task.scheduledStart == null)
              .toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _AgendaDaySection(
              date: date,
              occurrences: occurrences,
              anytime: anytime,
              onDateSelected: onDateSelected,
              showEmpty: true,
            ),
          );
        }),
      ],
    );
  }
}

class _DayView extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DayView({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final occurrences = provider.scheduledOccurrencesForDate(selectedDate);
    final anytime = provider
        .tasksForDate(selectedDate, includeCompleted: true)
        .where((task) => task.scheduledStart == null)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _WeekDateStrip(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        ),
        const SizedBox(height: 18),
        _CalendarModeIntro(
          title: _isToday(selectedDate)
              ? 'Today'
              : DateFormat('EEEE').format(selectedDate),
          subtitle: DateFormat('MMMM d, yyyy').format(selectedDate),
          selectedDate: selectedDate,
        ),
        const SizedBox(height: 18),
        _AgendaDaySection(
          date: selectedDate,
          occurrences: occurrences,
          anytime: anytime,
          onDateSelected: onDateSelected,
          showHeader: false,
          showEmpty: true,
        ),
      ],
    );
  }
}

class _MultiDayFlow extends StatelessWidget {
  final DateTime selectedDate;
  final int dayCount;
  final ValueChanged<DateTime> onDateSelected;

  const _MultiDayFlow({
    required this.selectedDate,
    required this.dayCount,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final days = List<DateTime>.generate(
      dayCount,
      (index) => selectedDate.add(Duration(days: index)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _CalendarModeIntro(
          title: dayCount == 3 ? '3-day flow' : 'Week flow',
          subtitle: dayCount == 3
              ? 'Compare the next three days side by side.'
              : '${DateFormat('MMM d').format(days.first)} – ${DateFormat('MMM d').format(days.last)}',
          selectedDate: selectedDate,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: dayCount == 3 ? 420 : 430,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = days[index];
              final occurrences =
                  provider.scheduledOccurrencesForDate(date);
              final anytime = provider
                  .tasksForDate(date, includeCompleted: true)
                  .where((task) => task.scheduledStart == null)
                  .toList();

              return _DayFlowColumn(
                date: date,
                occurrences: occurrences,
                anytime: anytime,
                width: dayCount == 3 ? 220 : 176,
                onTapDate: () => onDateSelected(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthView({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday - DateTime.monday),
    );

    final cells = List<DateTime>.generate(
      42,
      (index) => gridStart.add(Duration(days: index)),
    );

    final selectedOccurrences =
        provider.scheduledOccurrencesForDate(selectedDate);
    final selectedAnytime = provider
        .tasksForDate(selectedDate, includeCompleted: true)
        .where((task) => task.scheduledStart == null)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
      children: [
        _CalendarModeIntro(
          title: DateFormat('MMMM').format(selectedDate),
          subtitle: 'Tap any date to open its plan.',
          selectedDate: selectedDate,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              const _WeekdayHeader(),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.93,
                ),
                itemBuilder: (context, index) {
                  final date = cells[index];
                  final tasks = provider.tasksForDate(
                    date,
                    includeCompleted: true,
                  );
                  return _MonthDayCell(
                    date: date,
                    selectedDate: selectedDate,
                    currentMonth: selectedDate.month,
                    tasks: tasks,
                    onTap: () => onDateSelected(date),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isToday(selectedDate)
              ? 'Today'
              : DateFormat('EEEE, MMMM d').format(selectedDate),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _AgendaDaySection(
          date: selectedDate,
          occurrences: selectedOccurrences,
          anytime: selectedAnytime,
          onDateSelected: onDateSelected,
          showHeader: false,
          showEmpty: true,
        ),
      ],
    );
  }
}

class _CalendarModeIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime selectedDate;

  const _CalendarModeIntro({
    required this.title,
    required this.subtitle,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgendaDaySection extends StatelessWidget {
  final DateTime date;
  final List<TaskOccurrence> occurrences;
  final List<Task> anytime;
  final ValueChanged<DateTime> onDateSelected;
  final bool showHeader;
  final bool showEmpty;

  const _AgendaDaySection({
    required this.date,
    required this.occurrences,
    required this.anytime,
    required this.onDateSelected,
    this.showHeader = true,
    this.showEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = occurrences.isNotEmpty || anytime.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onDateSelected(date),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _isToday(date)
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(
                          '${date.day}',
                          style:
                              Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: _isToday(date)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!hasItems && showEmpty)
          _EmptyDay(
            compact: showHeader,
          )
        else ...[
          ...List.generate(occurrences.length, (index) {
            return _PlannerTimelineTask(
              occurrence: occurrences[index],
              isLast: index == occurrences.length - 1 && anytime.isEmpty,
            );
          }),
          if (anytime.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...anytime.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AnytimePlannerTask(
                  task: task,
                  date: date,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PlannerTimelineTask extends StatelessWidget {
  final TaskOccurrence occurrence;
  final bool isLast;

  const _PlannerTimelineTask({
    required this.occurrence,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final today = _dateOnly(DateTime.now());
    final occurrenceDay = _dateOnly(occurrence.start);
    final canToggle = task.recurrence == TaskRecurrence.none ||
        !occurrenceDay.isAfter(today);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Text(
                DateFormat('h:mm a').format(occurrence.start),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        occurrence.isCompleted ? AppTheme.success : color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push(
                    '/task/edit/${Uri.encodeComponent(task.id)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  decoration: occurrence.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${DateFormat('h:mm a').format(occurrence.start)} – ${DateFormat('h:mm a').format(occurrence.end)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (!occurrence.isCompleted)
                          IconButton(
                            tooltip: 'Start focus',
                            onPressed: () => context.push(
                              '/focus/setup?taskId=${Uri.encodeQueryComponent(task.id)}',
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                        IconButton(
                          tooltip: occurrence.isCompleted
                              ? 'Undo'
                              : 'Complete',
                          onPressed: canToggle
                              ? () => context
                                  .read<TaskProvider>()
                                  .setCompletedForDate(
                                    task.id,
                                    occurrence.start,
                                    !occurrence.isCompleted,
                                  )
                              : null,
                          icon: Icon(
                            occurrence.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: occurrence.isCompleted
                                ? AppTheme.success
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnytimePlannerTask extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _AnytimePlannerTask({
    required this.task,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final complete = provider.isTaskCompletedForDate(task, date);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          '/task/edit/${Uri.encodeComponent(task.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.all_inclusive_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration:
                        complete ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () =>
                    context.read<TaskProvider>().setCompletedForDate(
                          task.id,
                          date,
                          !complete,
                        ),
                icon: Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: complete ? AppTheme.success : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayFlowColumn extends StatelessWidget {
  final DateTime date;
  final List<TaskOccurrence> occurrences;
  final List<Task> anytime;
  final double width;
  final VoidCallback onTapDate;

  const _DayFlowColumn({
    required this.date,
    required this.occurrences,
    required this.anytime,
    required this.width,
    required this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isToday(date)
              ? Theme.of(context).colorScheme.primary.withOpacity(0.55)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTapDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _isToday(date)
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: _isToday(date)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: occurrences.isEmpty && anytime.isEmpty
                ? Center(
                    child: Text(
                      'Free',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView(
                    children: [
                      ...occurrences.map(
                        (occurrence) => _MiniTaskBlock(
                          occurrence: occurrence,
                        ),
                      ),
                      ...anytime.map(
                        (task) => _MiniAnytimeBlock(
                          task: task,
                          date: date,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniTaskBlock extends StatelessWidget {
  final TaskOccurrence occurrence;

  const _MiniTaskBlock({
    required this.occurrence,
  });

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          '/task/edit/${Uri.encodeComponent(task.id)}',
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('h:mm a').format(occurrence.start),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: occurrence.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAnytimeBlock extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _MiniAnytimeBlock({
    required this.task,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          '/task/edit/${Uri.encodeComponent(task.id)}',
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _WeekDateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDateStrip({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(selectedDate);
    final provider = context.watch<TaskProvider>();

    return Row(
      children: List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final selected = _sameDate(date, selectedDate);
        final count = provider
            .tasksForDate(date, includeCompleted: true)
            .length;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == 6 ? 0 : 5,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onDateSelected(date),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date).substring(0, 1),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: count > 0 ? 6 : 3,
                      height: count > 0 ? 6 : 3,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  final DateTime date;
  final DateTime selectedDate;
  final int currentMonth;
  final List<Task> tasks;
  final VoidCallback onTap;

  const _MonthDayCell({
    required this.date,
    required this.selectedDate,
    required this.currentMonth,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = _sameDate(date, selectedDate);
    final today = _isToday(date);
    final inMonth = date.month == currentMonth;
    final dots = tasks.take(3).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: today && !selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected || today
                    ? FontWeight.w900
                    : FontWeight.w600,
                color: inMonth
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.45),
              ),
            ),
            const Spacer(),
            if (dots.isNotEmpty)
              Wrap(
                spacing: 2,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: dots
                    .map(
                      (task) => Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _priorityColor(
                            task.priority,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool compact;

  const _EmptyDay({
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: compact ? 18 : 28,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No plan for this day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitPlannerBody extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _HabitPlannerBody({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final habits = provider.habitsForDate(selectedDate);
    final completed = habits
        .where(
          (habit) => provider.isCompletedForDate(
            habit,
            selectedDate,
          ),
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _WeekDateStripForHabits(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isToday(selectedDate)
                        ? 'Today’s habits'
                        : '${DateFormat('EEEE').format(selectedDate)} habits',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habits.isEmpty
                        ? 'No routines are scheduled for this date.'
                        : '$completed of ${habits.length} complete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (habits.isEmpty)
          _HabitEmptyState(
            hasAny: provider.habits.isNotEmpty,
          )
        else
          ...habits.map(
            (habit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HabitPlannerCard(
                habit: habit,
                date: selectedDate,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekDateStripForHabits extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDateStripForHabits({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(selectedDate);
    final provider = context.watch<HabitProvider>();

    return Row(
      children: List.generate(7, (index) {
        final date = start.add(Duration(days: index));
        final selected = _sameDate(date, selectedDate);
        final habits = provider.habitsForDate(date);
        final complete = habits.isNotEmpty &&
            habits.every(
              (habit) => provider.isCompletedForDate(
                habit,
                date,
              ),
            );

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onDateSelected(date),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date).substring(0, 1),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Icon(
                      complete
                          ? Icons.check_circle_rounded
                          : Icons.circle,
                      size: complete ? 8 : 5,
                      color: complete
                          ? AppTheme.success
                          : habits.isNotEmpty
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HabitPlannerCard extends StatelessWidget {
  final Habit habit;
  final DateTime date;

  const _HabitPlannerCard({
    required this.habit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final progress = provider.progressForDate(habit.id, date);
    final complete = provider.isCompletedForDate(habit, date);
    final ratio =
        (progress / habit.targetValue).clamp(0.0, 1.0).toDouble();

    final progressText = habit.goalType == HabitGoalType.checkIn
        ? (complete ? 'Done' : 'Check in')
        : '$progress / ${habit.targetValue} ${habit.unit}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(
          '/habit/${Uri.encodeComponent(habit.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  habit.icon,
                  color: habit.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      progressText,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    if (habit.goalType != HabitGoalType.checkIn) ...[
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          color: habit.color,
                          backgroundColor:
                              habit.color.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () =>
                    context.read<HabitProvider>().toggleCompleted(
                          habit.id,
                          date,
                        ),
                icon: Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: complete ? habit.color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitEmptyState extends StatelessWidget {
  final bool hasAny;

  const _HabitEmptyState({
    required this.hasAny,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            hasAny
                ? 'No habits scheduled today'
                : 'Build your first routine',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            hasAny
                ? 'Choose another date to see its routines.'
                : 'Use the single New habit button to add a routine that repeats on the days you choose.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
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
                  style:
                      Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing here.',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: task.plannedDate == null
                                  ? null
                                  : Text(
                                      DateFormat('EEE, MMM d')
                                          .format(task.plannedDate!),
                                    ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                              ),
                              onTap: () {
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
                  style:
                      Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: itemCount == 0
                      ? Center(
                          child: Text(
                            'Completed work will appear here.',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .onSurfaceVariant,
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
                                    fontWeight: FontWeight.w800,
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  'Occurrence ${DateFormat('EEE, MMM d').format(occurrence.start)}',
                                ),
                                onTap: () {
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

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _weekStart(DateTime date) {
  final day = _dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _isToday(DateTime date) => _sameDate(date, DateTime.now());

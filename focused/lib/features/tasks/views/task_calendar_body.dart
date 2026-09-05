import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/task.dart';
import '../../../models/task_occurrence.dart';
import '../../../models/task_recurrence.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../services/task_execution_analyzer.dart';
import '../../../theme/app_theme.dart';
import '../../planner/widgets/planner_header.dart';

class TaskCalendarBody extends StatelessWidget {
  final PlannerCalendarMode mode;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPickDate;

  const TaskCalendarBody({super.key, 
    required this.mode,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case PlannerCalendarMode.schedule:
        return _ScheduleView(
          selectedDate: selectedDate,
          onDateSelected: onDateSelected,
          onPickDate: onPickDate,
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
  final VoidCallback onPickDate;

  const _ScheduleView({
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPickDate,
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
          title: 'Create your plan',
          selectedDate: selectedDate,
          onPickDate: onPickDate,
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/task/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New task',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
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

  const _DayView({required this.selectedDate, required this.onDateSelected});

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
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/task/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New task',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (anytime.isNotEmpty) ...[
          _AnytimeCalendarStrip(date: selectedDate, tasks: anytime),
          const SizedBox(height: 14),
        ],
        _DayTimeGrid(date: selectedDate, occurrences: occurrences),
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
    final occurrencesByDay = <DateTime, List<TaskOccurrence>>{};
    final anytimeByDay = <DateTime, List<Task>>{};

    for (final day in days) {
      final key = _dateOnly(day);
      occurrencesByDay[key] = provider.scheduledOccurrencesForDate(day);
      anytimeByDay[key] = provider
          .tasksForDate(day, includeCompleted: true)
          .where((task) => task.scheduledStart == null)
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
      children: [
        _CalendarModeIntro(
          title: dayCount == 3 ? '3 days' : 'Week',
          subtitle: dayCount == 3
              ? '${DateFormat('MMM d').format(days.first)} – ${DateFormat('MMM d').format(days.last)}'
              : '${DateFormat('MMM d').format(days.first)} – ${DateFormat('MMM d').format(days.last)}',
          selectedDate: selectedDate,
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/task/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New task',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _MultiDayTimeGrid(
          days: days,
          occurrencesByDay: occurrencesByDay,
          anytimeByDay: anytimeByDay,
          onDateSelected: onDateSelected,
          compact: dayCount > 3,
        ),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthView({required this.selectedDate, required this.onDateSelected});

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

    final selectedOccurrences = provider.scheduledOccurrencesForDate(
      selectedDate,
    );
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
          action: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push('/task/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New task',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('planner-month-previous'),
                    tooltip: 'Previous month',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onDateSelected(
                      DateTime(selectedDate.year, selectedDate.month - 1, 1),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(selectedDate),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('planner-month-next'),
                    tooltip: 'Next month',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onDateSelected(
                      DateTime(selectedDate.year, selectedDate.month + 1, 1),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const _WeekdayHeader(),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
  final String? subtitle;
  final DateTime selectedDate;
  final VoidCallback? onPickDate;
  final Widget? action;

  const _CalendarModeIntro({
    required this.title,
    this.subtitle,
    required this.selectedDate,
    this.onPickDate,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (onPickDate != null) ...[
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(
                        alpha: isDark ? 0.20 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.35 : 0.20,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 22,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: _isToday(date)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.headlineMedium,
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
          _EmptyDay(compact: showHeader)
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
                child: _AnytimePlannerTask(task: task, date: date),
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

  const _PlannerTimelineTask({required this.occurrence, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final today = _dateOnly(DateTime.now());
    final occurrenceDay = _dateOnly(occurrence.start);
    final canToggle =
        task.recurrence == TaskRecurrence.none || !occurrenceDay.isAfter(today);
    final focusProvider = context.watch<FocusProvider>();
    final inFocus = focusProvider.isFocusingTaskOccurrence(
      task.id,
      occurrence.start,
    );
    final execution = const TaskExecutionAnalyzer().summarizeOccurrence(
      occurrence: occurrence,
      sessions: focusProvider.sessionHistory,
      analysesBySessionId: const {},
      activeTaskId: inFocus ? focusProvider.taskId : null,
      activeOccurrenceDate: inFocus ? focusProvider.taskOccurrenceDate : null,
      activeSessionStartedAt: inFocus ? focusProvider.sessionStartedAt : null,
      activeTaskScheduledStart: inFocus
          ? focusProvider.taskScheduledStart
          : null,
      activeTaskScheduledEnd: inFocus ? focusProvider.taskScheduledEnd : null,
      activeFocusIntervals: inFocus
          ? focusProvider.currentFocusIntervalsSnapshot
          : const [],
    );

    final effectiveColor = task.isSquadTask ? const Color(0xFF9B51E0) : color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 62,
            child: Center(
              child: Text(
                DateFormat('h:mm a').format(occurrence.start),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isLast)
                  Center(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: occurrence.isCompleted
                        ? AppTheme.success
                        : effectiveColor,
                    shape: BoxShape.circle,
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
                color: task.isSquadTask
                    ? const Color(0xFF9B51E0).withValues(alpha: 0.08)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: task.isSquadTask
                    ? null
                    : BorderRadius.circular(18),
                shape: task.isSquadTask
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: Color(0xFF9B51E0),
                          width: 1.5,
                        ),
                      )
                    : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push(
                    '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(occurrence.start)}',
                  ),
                  onLongPress: () => context.push(
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
                            color: effectiveColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          task.isSquadTask
                              ? 'assets/icon/group_task.svg'
                              : 'assets/icon/task_icon.svg',
                          width: 22,
                          height: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: occurrence.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (occurrence.isCompletedLate ||
                                      task.isCompletedLate) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '⚠️ Late',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (task.isSquadTask) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF9B51E0,
                                        ).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '👥 Squad',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF9B51E0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              if (inFocus)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Text(
                                      'IN FOCUS',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (execution.actualStart != null)
                                      Text(
                                        _startTimingLabel(
                                          execution.actualStart!,
                                          execution.plannedStart,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                  ],
                                )
                              else if (execution.hasStarted)
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      '${_shortDuration(execution.activeFocusDuration)} focused',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (execution.actualStart != null)
                                      Text(
                                        _startTimingLabel(
                                          execution.actualStart!,
                                          execution.plannedStart,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                )
                              else
                                Text(
                                  '${DateFormat('h:mm a').format(occurrence.start)} – ${DateFormat('h:mm a').format(occurrence.end)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: occurrence.isCompleted ? 'Undo' : 'Complete',
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

  const _AnytimePlannerTask({required this.task, required this.date});

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
          '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(date)}',
        ),
        onLongPress: () =>
            context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              task.isSquadTask
                  ? SvgPicture.asset(
                      'assets/icon/group_task.svg',
                      width: 18,
                      height: 18,
                    )
                  : const Icon(Icons.all_inclusive_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: complete ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: complete ? 'Undo' : 'Complete',
                onPressed: () => context
                    .read<TaskProvider>()
                    .setCompletedForDate(task.id, date, !complete),
                icon: Icon(
                  complete ? Icons.check_circle_rounded : Icons.circle_outlined,
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

class _AnytimeCalendarStrip extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;

  const _AnytimeCalendarStrip({required this.date, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.all_inclusive_rounded,
                size: 17,
                color: scheme.secondary,
              ),
              const SizedBox(width: 7),
              Text(
                'Anytime',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tasks
                .map((task) => _AnytimeCalendarChip(task: task, date: date))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AnytimeCalendarChip extends StatelessWidget {
  final Task task;
  final DateTime date;

  const _AnytimeCalendarChip({required this.task, required this.date});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final complete = provider.isTaskCompletedForDate(task, date);

    return GestureDetector(
      onLongPress: () =>
          context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
      child: ActionChip(
        avatar: complete
            ? const Icon(
                Icons.check_circle_rounded,
                size: 17,
                color: AppTheme.success,
              )
            : SvgPicture.asset(
                'assets/icon/task_icon.svg',
                width: 17,
                height: 17,
              ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        onPressed: () => context.push(
          '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(date)}',
        ),
      ),
    );
  }
}

class _DayTimeGrid extends StatelessWidget {
  final DateTime date;
  final List<TaskOccurrence> occurrences;

  const _DayTimeGrid({required this.date, required this.occurrences});

  static const double _hourHeight = 68;
  static const double _timeWidth = 52;
  static const double _topInset = 18;

  @override
  Widget build(BuildContext context) {
    final range = _visibleHourRange(occurrences);
    final startHour = range.$1;
    final endHour = range.$2;
    final hourCount = endHour - startHour;
    final gridHeight = _topInset + hourCount * _hourHeight;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: gridHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeWidth,
                child: Stack(
                  children: List.generate(hourCount, (index) {
                    final hour = startHour + index;
                    return Positioned(
                      top: _topInset + index * _hourHeight - 7,
                      left: 0,
                      right: 7,
                      child: Text(
                        _hourLabel(hour),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ...List.generate(hourCount + 1, (index) {
                      return Positioned(
                        top: _topInset + index * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                      );
                    }),
                    ...occurrences.map((occurrence) {
                      return _positionedGridTask(
                        context,
                        occurrence: occurrence,
                        startHour: startHour,
                        hourHeight: _hourHeight,
                        topInset: _topInset,
                        left: 8,
                        right: 10,
                      );
                    }),
                    if (_isToday(date))
                      _currentTimeIndicator(
                        context,
                        date: date,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: _hourHeight,
                        topInset: _topInset,
                      ),
                    if (occurrences.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'No timed tasks on this day.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
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
  }
}

class _MultiDayTimeGrid extends StatelessWidget {
  final List<DateTime> days;
  final Map<DateTime, List<TaskOccurrence>> occurrencesByDay;
  final Map<DateTime, List<Task>> anytimeByDay;
  final ValueChanged<DateTime> onDateSelected;
  final bool compact;

  const _MultiDayTimeGrid({
    required this.days,
    required this.occurrencesByDay,
    required this.anytimeByDay,
    required this.onDateSelected,
    required this.compact,
  });

  static const double _hourHeight = 58;
  static const double _timeWidth = 48;
  static const double _topInset = 18;

  @override
  Widget build(BuildContext context) {
    final allOccurrences = occurrencesByDay.values
        .expand((items) => items)
        .toList();
    final range = _visibleHourRange(allOccurrences);
    final startHour = range.$1;
    final endHour = range.$2;
    final hourCount = endHour - startHour;
    final gridHeight = _topInset + hourCount * _hourHeight;
    final columnWidth = compact ? 150.0 : 184.0;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 92),
                    SizedBox(
                      height: gridHeight,
                      child: Stack(
                        children: List.generate(hourCount, (index) {
                          final hour = startHour + index;
                          return Positioned(
                            top: _topInset + index * _hourHeight - 7,
                            left: 0,
                            right: 6,
                            child: Text(
                              _hourLabel(hour),
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              ...days.map((day) {
                final key = _dateOnly(day);
                final occurrences =
                    occurrencesByDay[key] ?? const <TaskOccurrence>[];
                final anytime = anytimeByDay[key] ?? const <Task>[];

                return SizedBox(
                  width: columnWidth,
                  child: Column(
                    children: [
                      _MultiDayHeader(
                        date: day,
                        anytimeCount: anytime.length,
                        onTap: () => onDateSelected(day),
                      ),
                      SizedBox(
                        height: gridHeight,
                        child: Stack(
                          children: [
                            ...List.generate(hourCount + 1, (index) {
                              return Positioned(
                                top: _topInset + index * _hourHeight,
                                left: 0,
                                right: 0,
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                              );
                            }),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              child: VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            ...occurrences.map((occurrence) {
                              return _positionedGridTask(
                                context,
                                occurrence: occurrence,
                                startHour: startHour,
                                hourHeight: _hourHeight,
                                topInset: _topInset,
                                left: 7,
                                right: 7,
                                compact: true,
                              );
                            }),
                            if (_isToday(day))
                              _currentTimeIndicator(
                                context,
                                date: day,
                                startHour: startHour,
                                endHour: endHour,
                                hourHeight: _hourHeight,
                                topInset: _topInset,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiDayHeader extends StatelessWidget {
  final DateTime date;
  final int anytimeCount;
  final VoidCallback onTap;

  const _MultiDayHeader({
    required this.date,
    required this.anytimeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: _isToday(date)
              ? scheme.primaryContainer.withOpacity(0.48)
              : scheme.surfaceContainerLow,
          border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('EEE').format(date),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _isToday(date)
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              anytimeCount == 0 ? 'Timed plan' : '$anytimeCount anytime',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Positioned _positionedGridTask(
  BuildContext context, {
  required TaskOccurrence occurrence,
  required int startHour,
  required double hourHeight,
  required double topInset,
  required double left,
  required double right,
  bool compact = false,
}) {
  final startMinutes = occurrence.start.hour * 60 + occurrence.start.minute;
  final gridStartMinutes = startHour * 60;
  final rawTop = (startMinutes - gridStartMinutes) / 60 * hourHeight;

  final dayEnd = DateTime(
    occurrence.start.year,
    occurrence.start.month,
    occurrence.start.day + 1,
  );
  final effectiveEnd = occurrence.end.isAfter(dayEnd) ? dayEnd : occurrence.end;
  final durationMinutes = effectiveEnd.difference(occurrence.start).inMinutes;
  final rawHeight = durationMinutes / 60 * hourHeight;
  final height = rawHeight
      .clamp(compact ? 24.0 : 30.0, compact ? 118.0 : 170.0)
      .toDouble();

  return Positioned(
    top: topInset + rawTop.clamp(0.0, double.infinity).toDouble() + 3,
    left: left,
    right: right,
    height: height,
    child: _GridTaskBlock(occurrence: occurrence, compact: compact),
  );
}

Widget _currentTimeIndicator(
  BuildContext context, {
  required DateTime date,
  required int startHour,
  required int endHour,
  required double hourHeight,
  required double topInset,
}) {
  final now = DateTime.now();
  if (!_sameDate(now, date)) {
    return const SizedBox.shrink();
  }

  final nowMinutes = now.hour * 60 + now.minute;
  final startMinutes = startHour * 60;
  final endMinutes = endHour * 60;
  if (nowMinutes < startMinutes || nowMinutes > endMinutes) {
    return const SizedBox.shrink();
  }

  final top = (nowMinutes - startMinutes) / 60 * hourHeight;
  final color = Theme.of(context).colorScheme.primary;

  return Positioned(
    top: topInset + top,
    left: 0,
    right: 0,
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(child: Container(height: 1.5, color: color)),
      ],
    ),
  );
}

class _GridTaskBlock extends StatelessWidget {
  final TaskOccurrence occurrence;
  final bool compact;

  const _GridTaskBlock({required this.occurrence, required this.compact});

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final color = _priorityColor(task.priority);
    final focusProvider = context.watch<FocusProvider>();
    final inFocus = focusProvider.isFocusingTaskOccurrence(
      task.id,
      occurrence.start,
    );

    return Material(
      color: color.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.11,
      ),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/task/${Uri.encodeComponent(task.id)}?date=${_dateQuery(occurrence.start)}',
        ),
        onLongPress: () =>
            context.push('/task/edit/${Uri.encodeComponent(task.id)}'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tiny = constraints.maxHeight < 39;
            final showTime = constraints.maxHeight >= 45;

            return Container(
              padding: EdgeInsets.fromLTRB(
                compact ? 7 : 9,
                tiny ? 3 : (compact ? 6 : 8),
                compact ? 5 : 7,
                tiny ? 3 : (compact ? 6 : 8),
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: occurrence.isCompleted
                        ? AppTheme.success
                        : inFocus
                        ? Theme.of(context).colorScheme.primary
                        : color,
                    width: inFocus ? 4 : 3,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 13,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      decoration: occurrence.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (inFocus && constraints.maxHeight >= 42) ...[
                    const SizedBox(height: 2),
                    Text(
                      'IN FOCUS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 8.5 : null,
                        height: 1.0,
                      ),
                    ),
                  ] else if (showTime) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('h:mm').format(occurrence.start)}–${DateFormat('h:mm a').format(occurrence.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: compact ? 9 : null,
                        height: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

(int, int) _visibleHourRange(List<TaskOccurrence> occurrences) {
  var startHour = 6;
  var endHour = 22;

  if (occurrences.isNotEmpty) {
    final earliest = occurrences
        .map((item) => item.start.hour)
        .reduce((a, b) => a < b ? a : b);
    final latest = occurrences
        .map((item) {
          if (!_sameDate(item.start, item.end)) {
            return 24;
          }
          return item.end.minute == 0 ? item.end.hour : item.end.hour + 1;
        })
        .reduce((a, b) => a > b ? a : b);

    startHour = earliest < startHour ? earliest : startHour;
    endHour = latest > endHour ? latest : endHour;
  }

  startHour = startHour.clamp(0, 23).toInt();
  endHour = endHour.clamp(startHour + 1, 24).toInt();
  return (startHour, endHour);
}

String _hourLabel(int hour) {
  final normalized = hour == 24 ? 0 : hour;
  final period = normalized < 12 ? 'AM' : 'PM';
  final display = normalized % 12 == 0 ? 12 : normalized % 12;
  return '$display $period';
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected || today
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: inMonth
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.45),
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
                          color: _priorityColor(task.priority),
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

  const _EmptyDay({this.compact = false});

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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
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

String _startTimingLabel(DateTime actualStart, DateTime plannedStart) {
  final offset = actualStart.difference(plannedStart);
  if (offset.compareTo(const Duration(minutes: 5)) <= 0 && !offset.isNegative) {
    return 'On time';
  }
  if (offset.isNegative) {
    final early = Duration(microseconds: -offset.inMicroseconds);
    return '${_shortDuration(early)} early';
  }
  return '${_shortDuration(offset)} late';
}

String _shortDuration(Duration value) {
  final minutes = value.inMinutes.abs();
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _dateQuery(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

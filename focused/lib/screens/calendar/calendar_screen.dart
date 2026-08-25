import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

enum CalendarViewType { month, week, day }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewType _view = CalendarViewType.day;

  DateTime _selectedDate = DateTime(2026, 8, 25);

  final List<_MockCalendarEvent> _events = const [
    _MockCalendarEvent(
      title: 'Morning exercise',
      start: '07:00',
      end: '08:00',
      color: Color(0xFF34B27B),
    ),
    _MockCalendarEvent(
      title: 'Project work',
      start: '09:00',
      end: '10:30',
      color: AppTheme.primaryBlue,
    ),
    _MockCalendarEvent(
      title: 'Lunch',
      start: '12:00',
      end: '13:00',
      color: Color(0xFFFFB84D),
    ),
    _MockCalendarEvent(
      title: 'Study Flutter',
      start: '14:00',
      end: '16:00',
      color: Color(0xFF8E67D4),
    ),
    _MockCalendarEvent(
      title: 'Read',
      start: '18:00',
      end: '19:00',
      color: Color(0xFF42A5F5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarControls(
          view: _view,
          onChanged: (value) {
            setState(() {
              _view = value;
            });
          },
        ),
        Expanded(
          child: switch (_view) {
            CalendarViewType.month => _buildMonthView(),
            CalendarViewType.week => _buildWeekView(),
            CalendarViewType.day => _buildDayView(),
          },
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _CalendarHeader(title: 'August 2026', onPrevious: () {}, onNext: () {}),

        const SizedBox(height: 18),

        _MonthCalendar(
          selectedDate: _selectedDate,
          onSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),

        const SizedBox(height: 28),

        Text(
          'Tuesday, August 25',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 14),

        ..._events
            .take(3)
            .map(
              (event) => _CompactEventCard(
                event: event,
                onTap: () {
                  context.push('/calendar/event/edit');
                },
              ),
            ),

        const SizedBox(height: 18),

        _AddEventButton(
          onPressed: () {
            context.push('/calendar/event/new');
          },
        ),
      ],
    );
  }

  Widget _buildWeekView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _CalendarHeader(
          title: 'Aug 24 – Aug 30',
          onPrevious: () {},
          onNext: () {},
        ),

        const SizedBox(height: 18),

        _WeekSelector(
          selectedDate: _selectedDate,
          onSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),

        const SizedBox(height: 28),

        Text(
          'Tuesday, August 25',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 18),

        ..._events.map(
          (event) => _TimelineEvent(
            event: event,
            onTap: () {
              context.push('/calendar/event/edit');
            },
          ),
        ),

        const SizedBox(height: 18),

        _AddEventButton(
          onPressed: () {
            context.push('/calendar/event/new');
          },
        ),
      ],
    );
  }

  Widget _buildDayView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _CalendarHeader(title: 'August 2026', onPrevious: () {}, onNext: () {}),

        const SizedBox(height: 16),

        _WeekSelector(
          selectedDate: _selectedDate,
          onSelected: (date) {
            setState(() {
              _selectedDate = date;
            });
          },
        ),

        const SizedBox(height: 26),

        Row(
          children: [
            Expanded(
              child: Text(
                'Tuesday, August 25',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('Today')),
          ],
        ),

        const SizedBox(height: 14),

        ..._events.map(
          (event) => _TimelineEvent(
            event: event,
            onTap: () {
              context.push('/calendar/event/edit');
            },
          ),
        ),

        const SizedBox(height: 18),

        _AddEventButton(
          onPressed: () {
            context.push('/calendar/event/new');
          },
        ),
      ],
    );
  }
}

class _CalendarControls extends StatelessWidget {
  final CalendarViewType view;
  final ValueChanged<CalendarViewType> onChanged;

  const _CalendarControls({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<CalendarViewType>(
        segments: const [
          ButtonSegment(value: CalendarViewType.month, label: Text('Month')),
          ButtonSegment(value: CalendarViewType.week, label: Text('Week')),
          ButtonSegment(value: CalendarViewType.day, label: Text('Day')),
        ],
        selected: {view},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          onChanged(selection.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarHeader({
    required this.title,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  const _MonthCalendar({required this.selectedDate, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const weekdayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final firstDay = DateTime(2026, 8, 1);

    final leadingEmptyDays = firstDay.weekday - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: weekdayNames
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 14),

          GridView.builder(
            itemCount: leadingEmptyDays + 31,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays) {
                return const SizedBox();
              }

              final day = index - leadingEmptyDays + 1;

              final date = DateTime(2026, 8, day);

              final selected =
                  selectedDate.year == date.year &&
                  selectedDate.month == date.month &&
                  selectedDate.day == date.day;

              final hasEvent = [
                3,
                6,
                8,
                11,
                14,
                17,
                21,
                25,
                26,
                29,
              ].contains(day);

              return InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () {
                  onSelected(date);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryBlue
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: hasEvent
                            ? AppTheme.primaryBlue
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  const _WeekSelector({required this.selectedDate, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final days = [
      DateTime(2026, 8, 24),
      DateTime(2026, 8, 25),
      DateTime(2026, 8, 26),
      DateTime(2026, 8, 27),
      DateTime(2026, 8, 28),
      DateTime(2026, 8, 29),
      DateTime(2026, 8, 30),
    ];

    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(days.length, (index) {
        final date = days[index];

        final selected =
            selectedDate.year == date.year &&
            selectedDate.month == date.month &&
            selectedDate.day == date.day;

        return InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            onSelected(date);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text(
                  names[index],
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryBlue : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final _MockCalendarEvent event;
  final VoidCallback onTap;

  const _TimelineEvent({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                event.start,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: event.color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(20),
                  border: Border(
                    left: BorderSide(color: event.color, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${event.start} – ${event.end}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEventCard extends StatelessWidget {
  final _MockCalendarEvent event;
  final VoidCallback onTap;

  const _CompactEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${event.start} – ${event.end}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.50),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AddEventButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddEventButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add event',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MockCalendarEvent {
  final String title;
  final String start;
  final String end;
  final Color color;

  const _MockCalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.color,
  });
}

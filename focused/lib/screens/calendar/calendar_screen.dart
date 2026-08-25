import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          children: [
            Text(
              'August 2026',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
          ],
        ),

        const SizedBox(height: 16),

        const _WeekSelector(),

        const SizedBox(height: 26),

        Text(
          'Tuesday, August 25',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 20),

        const _TimelineEvent(
          time: '07:00',
          endTime: '08:00',
          title: 'Morning exercise',
          color: Color(0xFF34B27B),
        ),

        const _TimelineEvent(
          time: '09:00',
          endTime: '10:30',
          title: 'Project work',
          color: AppTheme.primaryBlue,
        ),

        const _TimelineEvent(
          time: '12:00',
          endTime: '13:00',
          title: 'Lunch',
          color: Color(0xFFFFB84D),
        ),

        const _TimelineEvent(
          time: '14:00',
          endTime: '16:00',
          title: 'Study Flutter',
          color: Color(0xFF8E67D4),
        ),

        const _TimelineEvent(
          time: '18:00',
          endTime: '19:00',
          title: 'Read',
          color: Color(0xFF42A5F5),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
          ),
        ),
      ],
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector();

  @override
  Widget build(BuildContext context) {
    final days = [
      ('Mon', '24'),
      ('Tue', '25'),
      ('Wed', '26'),
      ('Thu', '27'),
      ('Fri', '28'),
      ('Sat', '29'),
      ('Sun', '30'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final selected = day.$2 == '25';

        return Column(
          children: [
            Text(
              day.$1,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.50),
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
                day.$2,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : null,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final String time;
  final String endTime;
  final String title;
  final Color color;

  const _TimelineEvent({
    required this.time,
    required this.endTime,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.11),
                borderRadius: BorderRadius.circular(18),
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$time – $endTime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

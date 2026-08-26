import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

import 'package:go_router/go_router.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text(
          'Good morning',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          currentDate,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: const [
            Expanded(
              child: _SummaryCard(
                icon: Icons.local_fire_department_rounded,
                value: '12',
                label: 'Day streak',
                iconColor: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.timer_rounded,
                value: '2h 40m',
                label: 'Focused today',
                iconColor: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const _SectionTitle(title: 'Critical', color: Color(0xFFFF6B5E)),

        const SizedBox(height: 10),

        const _TaskTile(
          title: 'Finish assignment',
          subtitle: '90 min • Due today',
          color: Color(0xFFFF6B5E),
        ),

        const _TaskTile(
          title: 'Review project presentation',
          subtitle: '45 min',
          color: Color(0xFFFF6B5E),
        ),

        const SizedBox(height: 18),

        const _SectionTitle(title: 'Important', color: AppTheme.primaryBlue),

        const SizedBox(height: 10),

        const _TaskTile(
          title: 'Study Flutter',
          subtitle: '60 min',
          color: AppTheme.primaryBlue,
        ),

        const SizedBox(height: 18),

        const _SectionTitle(title: 'Growth', color: Color(0xFF34B27B)),

        const SizedBox(height: 10),

        const _TaskTile(
          title: 'Read 20 pages',
          subtitle: '30 min',
          color: Color(0xFF34B27B),
        ),

        const SizedBox(height: 26),

        const _SectionTitle(
          title: 'Today\'s schedule',
          color: AppTheme.primaryBlue,
        ),

        const SizedBox(height: 10),

        const _ScheduleCard(),

        const SizedBox(height: 26),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Habits', color: AppTheme.primaryBlue),
            TextButton(onPressed: () {}, child: const Text('View all')),
          ],
        ),

        const SizedBox(height: 8),

        const _HabitTile(
          icon: Icons.water_drop_rounded,
          title: 'Drink water',
          progress: '5 / 8 cups',
          color: Color(0xFF42A5F5),
        ),

        const _HabitTile(
          icon: Icons.menu_book_rounded,
          title: 'Read',
          progress: '12 / 20 pages',
          color: Color(0xFF8E67D4),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
              context.push('/focus/setup');
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Start Focus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _TaskTile({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
          const Icon(Icons.more_vert_rounded, size: 20),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          _ScheduleItem(
            time: '09:00',
            title: 'Project work',
            color: AppTheme.primaryBlue,
          ),
          SizedBox(height: 18),
          _ScheduleItem(
            time: '13:00',
            title: 'Study session',
            color: Color(0xFF8E67D4),
          ),
          SizedBox(height: 18),
          _ScheduleItem(
            time: '17:30',
            title: 'Exercise',
            color: Color(0xFF34B27B),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final Color color;

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String progress;
  final Color color;

  const _HabitTile({
    required this.icon,
    required this.title,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  progress,
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
    );
  }
}

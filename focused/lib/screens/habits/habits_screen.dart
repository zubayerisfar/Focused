import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const _DateSelector(),

        const SizedBox(height: 26),

        Row(
          children: [
            Text(
              'Today',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () {
                context.push('/habit/new');
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Habit'),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _HabitCard(
          icon: Icons.fitness_center_rounded,
          title: 'Exercise',
          subtitle: '4 total days',
          progress: 0.75,
          color: const Color(0xFF34B27B),
          onTap: () {
            context.push('/habit/details');
          },
        ),

        _HabitCard(
          icon: Icons.water_drop_rounded,
          title: 'Drink Water',
          subtitle: '5 / 8 cups',
          progress: 0.62,
          color: const Color(0xFF42A5F5),
          onTap: () {
            context.push('/habit/details');
          },
        ),

        _HabitCard(
          icon: Icons.menu_book_rounded,
          title: 'Read',
          subtitle: '12 / 20 pages',
          progress: 0.60,
          color: const Color(0xFF8E67D4),
          onTap: () {
            context.push('/habit/details');
          },
        ),

        _HabitCard(
          icon: Icons.wb_sunny_rounded,
          title: 'Early to Rise',
          subtitle: 'Completed today',
          progress: 1,
          color: const Color(0xFFFFB84D),
          onTap: () {
            context.push('/habit/details');
          },
        ),

        _HabitCard(
          icon: Icons.restaurant_rounded,
          title: 'Eat Fruits',
          subtitle: '9 total days',
          progress: 0.45,
          color: const Color(0xFFFF7A90),
          onTap: () {
            context.push('/habit/details');
          },
        ),
      ],
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector();

  @override
  Widget build(BuildContext context) {
    final days = [
      ('Wed', '20'),
      ('Thu', '21'),
      ('Fri', '22'),
      ('Sat', '23'),
      ('Sun', '24'),
      ('Mon', '25'),
      ('Tue', '26'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) {
        final selected = day.$2 == '25';

        return InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text(
                  day.$1,
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
                    day.$2,
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
      }).toList(),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final VoidCallback onTap;

  const _HabitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.48),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              progress >= 1
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: progress >= 1 ? color : null,
            ),
          ],
        ),
      ),
    );
  }
}

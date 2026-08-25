import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class HabitDetailsScreen extends StatefulWidget {
  const HabitDetailsScreen({super.key});

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> {
  int _progress = 12;

  final int _target = 20;

  @override
  Widget build(BuildContext context) {
    final progressValue = (_progress / _target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Habit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/habit/edit');
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0x198E67D4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF8E67D4),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Every weekday', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: progressValue,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(
                            0xFF8E67D4,
                          ).withOpacity(0.12),
                          color: const Color(0xFF8E67D4),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_progress',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '/ $_target pages',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (_progress > 0) {
                            setState(() {
                              _progress--;
                            });
                          }
                        },
                        child: const Text('- 1'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (_progress < _target) {
                            setState(() {
                              _progress++;
                            });
                          }
                        },
                        child: const Text('+ 1'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        _progress = _target;
                      });
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Complete Today',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          Text(
            'This week',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 14),

          const _WeeklyHistory(),

          const SizedBox(height: 26),

          Text(
            'Progress',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 14),

          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '6',
                  label: 'Day streak',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '18',
                  label: 'Total days',
                  icon: Icons.check_circle_rounded,
                  color: Color(0xFF34B27B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '82%',
                  label: 'Completion',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '9',
                  label: 'Best streak',
                  icon: Icons.emoji_events_rounded,
                  color: Color(0xFFFFB84D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyHistory extends StatelessWidget {
  const _WeeklyHistory();

  @override
  Widget build(BuildContext context) {
    const days = [
      ('Mon', true),
      ('Tue', true),
      ('Wed', true),
      ('Thu', false),
      ('Fri', true),
      ('Sat', false),
      ('Sun', false),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((item) {
          final completed = item.$2;

          return Column(
            children: [
              Text(
                item.$1,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFF8E67D4)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: completed
                      ? null
                      : Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.35),
                          width: 1.5,
                        ),
                ),
                child: completed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
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
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.50),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(
          'Ready to focus?',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a task, remove distractions, and make progress.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),

        const SizedBox(height: 28),

        // Today's focus summary
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.timer_rounded,
                value: '2h 40m',
                label: 'Focused today',
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _SummaryCard(
                icon: Icons.bolt_rounded,
                value: '160',
                label: 'Points today',
                color: Color(0xFF8E67D4),
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),

        Text(
          'Current streak',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 42,
                color: Colors.orange,
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '12 days',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text('Keep it going'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        Text(
          'Last session',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0x184D7CFE),
                child: Icon(Icons.code_rounded, color: AppTheme.primaryBlue),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Flutter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('50 min • Completed', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.check_circle_rounded, color: Color(0xFF34B27B)),
            ],
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          height: 60,
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
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
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
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
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

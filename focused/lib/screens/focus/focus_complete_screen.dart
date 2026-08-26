import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FocusCompleteScreen extends StatelessWidget {
  const FocusCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          children: [
            const SizedBox(height: 30),

            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF34B27B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Color(0xFF34B27B),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Nice work!',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            Text(
              'You completed your focus session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 38),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  _ResultRow(
                    icon: Icons.timer_rounded,
                    title: 'Focused time',
                    value: '2h 20m',
                    color: AppTheme.primaryBlue,
                  ),
                  Divider(height: 30),
                  _ResultRow(
                    icon: Icons.check_circle_rounded,
                    title: 'Focus blocks',
                    value: '3',
                    color: Color(0xFF34B27B),
                  ),
                  Divider(height: 30),
                  _ResultRow(
                    icon: Icons.bolt_rounded,
                    title: 'Points earned',
                    value: '+160',
                    color: Color(0xFF8E67D4),
                  ),
                  Divider(height: 30),
                  _ResultRow(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Current streak',
                    value: '12 days',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Your streak is safe for today.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 34),

            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: () {
                  context.go('/');
                },
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ResultRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

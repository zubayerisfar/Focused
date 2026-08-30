import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            children: [
              const Spacer(),

              // App icon placeholder
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.track_changes_rounded,
                  size: 46,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Focused',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 12),

              Text(
                'Plan your day. Build better habits.\nDo focused work.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.58),
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const _FeatureRow(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Plan tasks and priorities',
                    ),
                    const SizedBox(height: 18),
                    const _FeatureRow(
                      icon: Icons.calendar_month_outlined,
                      title: 'Sync with Google Calendar',
                    ),
                    const SizedBox(height: 18),
                    const _FeatureRow(
                      icon: Icons.timer_outlined,
                      title: 'Build focus streaks',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton(
                  onPressed: () {
                    // Static phase only.
                    // Later this will trigger Google Sign-In.
                    context.go('/');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleLetter(),
                      SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Your tasks, habits and calendar will stay synchronized across your devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 14),
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

class _GoogleLetter extends StatelessWidget {
  const _GoogleLetter();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryBlue,
      ),
    );
  }
}

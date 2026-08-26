import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class UsagePermissionScreen extends StatelessWidget {
  const UsagePermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usage Access')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 44,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Understand your digital habits',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Focused needs Android Usage Access to measure how long you use other apps and whether they interrupt focus sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.62),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _PermissionFeature(
                      icon: Icons.phone_android_rounded,
                      title: 'Daily app usage',
                      description:
                          'See total screen time and per-app usage for the day, week, and month.',
                    ),
                    const SizedBox(height: 14),
                    const _PermissionFeature(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Usage comparisons',
                      description:
                          'Compare today with yesterday and this week with last week.',
                    ),
                    const SizedBox(height: 14),
                    const _PermissionFeature(
                      icon: Icons.timer_outlined,
                      title: 'Focus interruption analysis',
                      description:
                          'Match app activity against focus-session times to estimate distracted and effective focus time.',
                    ),
                    const SizedBox(height: 24),
                    const _PrivacyCard(),
                    const SizedBox(height: 16),
                    const _PermissionStateCard(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Static UI only for now. Android Usage Access integration comes in Stage 10.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'Grant Usage Access',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.58),
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

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF34B27B).withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF34B27B)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private by default',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Raw app-usage history stays on this device by default. Only aggregated wellbeing summaries may be synced later if you choose.',
                  style: TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStateCard extends StatelessWidget {
  const _PermissionStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, size: 10, color: Color(0xFFFF8A65)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Permission status',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Not granted',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF8A65),
            ),
          ),
        ],
      ),
    );
  }
}

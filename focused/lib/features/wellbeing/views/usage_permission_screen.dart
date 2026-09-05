import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usage_access_status.dart';
import '../providers/usage_provider.dart';
import '../../../core/theme/app_theme.dart';

class UsagePermissionScreen extends StatelessWidget {
  const UsagePermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final status = usageProvider.accessStatus;
    final granted = status == UsageAccessStatus.granted;
    final busy = status == UsageAccessStatus.checking || usageProvider.isRefreshing;

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
                        child: Icon(
                          granted
                              ? Icons.verified_user_outlined
                              : Icons.shield_outlined,
                          size: 44,
                          color: granted
                              ? const Color(0xFF34B27B)
                              : AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      granted
                          ? 'Usage Access is connected'
                          : 'Understand your digital habits',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      granted
                          ? 'Focused can now read Android UsageStats and convert foreground activity into local app-usage intervals.'
                          : 'Focused needs Android Usage Access to measure how long you use other apps and whether they interrupt focus sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.62),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _PermissionFeature(
                      icon: Icons.phone_android_rounded,
                      title: 'Real daily app usage',
                      description:
                          'Read Android foreground-app events and build actual per-app usage for today and yesterday.',
                    ),
                    const SizedBox(height: 14),
                    const _PermissionFeature(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Usage comparisons',
                      description:
                          'Compare measured app usage with yesterday instead of using demo values.',
                    ),
                    const SizedBox(height: 14),
                    const _PermissionFeature(
                      icon: Icons.timer_outlined,
                      title: 'Focus interruption analysis',
                      description:
                          'Read app activity during the exact focus-session window so distracting time can be measured.',
                    ),
                    const SizedBox(height: 24),
                    const _PrivacyCard(),
                    const SizedBox(height: 16),
                    _PermissionStateCard(
                      status: status,
                      isRefreshing: usageProvider.isRefreshing,
                      lastUpdatedAt: usageProvider.lastUpdatedAt,
                      error: usageProvider.lastError,
                    ),
                    if (granted) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : usageProvider.openUsageAccessSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Manage Usage Access in Android'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: busy || status == UsageAccessStatus.unsupported
                      ? null
                      : () async {
                          if (granted) {
                            await context
                                .read<UsageProvider>()
                                .refreshPermissionAndUsage(force: true);
                          } else {
                            await context
                                .read<UsageProvider>()
                                .requestUsageAccess();
                          }
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          granted
                              ? Icons.refresh_rounded
                              : Icons.open_in_new_rounded,
                        ),
                  label: Text(
                    granted ? 'Refresh real usage' : 'Grant Usage Access',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.58),
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
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Raw app-usage intervals are stored locally on this device. Focused does not upload them to Firebase in this stage.',
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
  final UsageAccessStatus status;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;
  final String? error;

  const _PermissionStateCard({
    required this.status,
    required this.isRefreshing,
    required this.lastUpdatedAt,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(status, isRefreshing);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: presentation.color),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Permission status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                presentation.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: presentation.color,
                ),
              ),
            ],
          ),
          if (lastUpdatedAt != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last real usage refresh: ${_formatTimestamp(lastUpdatedAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.55),
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Color(0xFFFF8A65),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _PermissionPresentation _presentationFor(
    UsageAccessStatus status,
    bool refreshing,
  ) {
    if (refreshing) {
      return const _PermissionPresentation(
        label: 'Refreshing',
        color: AppTheme.primaryBlue,
      );
    }

    switch (status) {
      case UsageAccessStatus.granted:
        return const _PermissionPresentation(
          label: 'Granted',
          color: Color(0xFF34B27B),
        );
      case UsageAccessStatus.denied:
        return const _PermissionPresentation(
          label: 'Not granted',
          color: Color(0xFFFF8A65),
        );
      case UsageAccessStatus.unsupported:
        return const _PermissionPresentation(
          label: 'Android only',
          color: Colors.grey,
        );
      case UsageAccessStatus.error:
        return const _PermissionPresentation(
          label: 'Error',
          color: Colors.redAccent,
        );
      case UsageAccessStatus.checking:
      case UsageAccessStatus.unknown:
        return const _PermissionPresentation(
          label: 'Checking',
          color: AppTheme.primaryBlue,
        );
    }
  }
}

class _PermissionPresentation {
  final String label;
  final Color color;

  const _PermissionPresentation({
    required this.label,
    required this.color,
  });
}

String _formatTimestamp(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/usage_access_status.dart';
import '../providers/usage_provider.dart';

class UsagePermissionScreen extends StatelessWidget {
  const UsagePermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final status = usageProvider.accessStatus;
    final granted = status == UsageAccessStatus.granted;
    final busy =
        status == UsageAccessStatus.checking || usageProvider.isRefreshing;

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Activity',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 12),
                    // Header Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: granted
                              ? const Color(0xFF58CC02).withValues(alpha: 0.14)
                              : const Color(0xFF1CB0F6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          granted
                              ? Icons.check_circle_rounded
                              : Icons.query_stats_rounded,
                          size: 40,
                          color: granted
                              ? const Color(0xFF58CC02)
                              : const Color(0xFF1CB0F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      granted ? 'Usage Access Enabled' : 'Enable Usage Access',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      granted
                          ? 'Focused is actively recording app screen time and focus distraction metrics locally.'
                          : 'Grant Android permission so Focused can accurately calculate daily screen time and distraction sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Feature highlights (Clean & Minimal)
                    _FeatureRow(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Precise Screen Time',
                      subtitle:
                          'Track foreground duration for your apps with Digital Wellbeing accuracy.',
                      scheme: scheme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.shield_outlined,
                      title: 'Focus Guard & Limits',
                      subtitle:
                          'Detect when distracting apps are opened during active focus sessions.',
                      scheme: scheme,
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.lock_outline_rounded,
                      title: '100% On-Device & Private',
                      subtitle:
                          'Your usage stats stay on your device and are never sold or shared.',
                      scheme: scheme,
                    ),

                    const SizedBox(height: 24),

                    // Status Indicator Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? scheme.surfaceContainerHigh
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusColor(status, busy),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusTitle(status, busy),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (usageProvider.lastUpdatedAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Synced ${_formatTimestamp(usageProvider.lastUpdatedAt!)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (granted)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: _statusColor(status, busy),
                            ),
                        ],
                      ),
                    ),

                    if (granted) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : usageProvider.openUsageAccessSettings,
                          child: Text(
                            'Open system settings',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom Action Button
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: granted
                        ? const Color(0xFF58CC02) // Duo Green
                        : const Color(0xFF1CB0F6), // Duo Vibrant Cyan
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
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
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              granted
                                  ? Icons.refresh_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              granted
                                  ? 'Refresh Usage Data'
                                  : 'Allow Usage Access',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(UsageAccessStatus status, bool busy) {
    if (busy) return const Color(0xFF1CB0F6);
    switch (status) {
      case UsageAccessStatus.granted:
        return const Color(0xFF58CC02);
      case UsageAccessStatus.denied:
        return const Color(0xFFFF9600);
      case UsageAccessStatus.error:
        return const Color(0xFFFF4B4B);
      case UsageAccessStatus.unsupported:
        return Colors.grey;
      case UsageAccessStatus.checking:
      case UsageAccessStatus.unknown:
        return const Color(0xFF1CB0F6);
    }
  }

  String _statusTitle(UsageAccessStatus status, bool busy) {
    if (busy) return 'Checking permission...';
    switch (status) {
      case UsageAccessStatus.granted:
        return 'Access Granted';
      case UsageAccessStatus.denied:
        return 'Permission Required';
      case UsageAccessStatus.error:
        return 'Error checking permission';
      case UsageAccessStatus.unsupported:
        return 'Android Only';
      case UsageAccessStatus.checking:
      case UsageAccessStatus.unknown:
        return 'Checking status...';
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme scheme;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1CB0F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1CB0F6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
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

String _formatTimestamp(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

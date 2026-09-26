import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cloud_sync_provider.dart';

class CloudSyncScreen extends StatelessWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cloud Sync',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_sync_rounded, color: scheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sync.statusLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sync.lastSyncAt != null
                                ? 'Last synced: ${_formatDateTime(sync.lastSyncAt!.toLocal())}'
                                : 'Not synced yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sync.isSyncing)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Your tasks, habits, focus sessions, and profile synchronize seamlessly across all your devices with your Focused account.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
          if (sync.errorMessage != null) ...[
            const SizedBox(height: 14),
            Material(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sync.errorMessage!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: sync.canSync ? () => _triggerSync(context) : null,
              icon: const Icon(Icons.sync_rounded),
              label: Text(
                sync.isSyncing ? 'Syncing…' : 'Sync Now',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sync Details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Account Status',
            value: sync.canSync || sync.lastSyncAt != null ? 'Connected' : 'Sign in required',
          ),
          _InfoRow(
            label: 'Last Sync',
            value: sync.lastSyncAt == null
                ? 'Never'
                : _formatDateTime(sync.lastSyncAt!.toLocal()),
          ),
          if (sync.lastResult != null) ...[
            _InfoRow(
              label: 'Changes Uploaded',
              value: '${sync.lastResult!.pushed}',
            ),
            _InfoRow(
              label: 'Changes Downloaded',
              value: '${sync.lastResult!.pulled}',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _triggerSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await context.read<CloudSyncProvider>().syncNow(
        isManual: true,
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sync complete · ${result.pushed} uploaded, ${result.pulled} downloaded.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final errorText = e.toString();
      final msg = errorText.contains('No internet connection')
          ? 'No internet connection. Connect to the internet and try again.'
          : (context.read<CloudSyncProvider>().errorMessage ??
                'Cloud sync could not finish.');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
}

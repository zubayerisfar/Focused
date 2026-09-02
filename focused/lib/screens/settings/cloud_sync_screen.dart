import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cloud_sync_provider.dart';
import '../../services/cloud_sync_service.dart';

class CloudSyncScreen extends StatelessWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncProvider>();
    final scheme = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.all(18),
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
                    Icon(Icons.cloud_sync_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sync.statusLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (sync.isSyncing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Tasks, recurring-task completion history, habits, habit progress, focus history, profile and Focused settings can sync through your Firebase account.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Raw Android screen-time, app-open events, notification events and foreground-app history stay on this device.',
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
                child: Text(
                  sync.errorMessage!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          if (sync.isNewDevice) ...[
            const SizedBox(height: 14),
            Material(
              color: scheme.primaryContainer.withOpacity(0.45),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'New Android device detected. Sync now to restore tasks, habits, focus history and profile. Screen-time and app-open history are read locally from Android UsageStats; notification history begins after notification access is enabled.',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: sync.canSync
                  ? () => _triggerSync(context, CloudSyncMode.bidirectional)
                  : null,
              icon: const Icon(Icons.sync_rounded),
              label: Text(sync.isSyncing ? 'Syncing…' : 'Smart Sync (Bidirectional)'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: sync.canSync
                      ? () => _triggerSync(context, CloudSyncMode.downloadOnly)
                      : null,
                  icon: const Icon(Icons.cloud_download_rounded, size: 18),
                  label: const Text('Download Cloud'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: sync.canSync
                      ? () => _triggerSync(context, CloudSyncMode.uploadOnly)
                      : null,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: const Text('Upload Local'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(label: 'Device', value: sync.deviceName ?? 'Focused device'),
          _InfoRow(
            label: 'Installation ID',
            value: sync.deviceId == null
                ? 'Preparing…'
                : _shortDeviceId(sync.deviceId!),
          ),
          _InfoRow(
            label: 'Last sync',
            value: sync.lastSyncAt == null
                ? 'Not synced on this run'
                : _formatDateTime(sync.lastSyncAt!.toLocal()),
          ),
          if (sync.lastResult != null) ...[
            _InfoRow(
              label: 'Uploaded',
              value: '${sync.lastResult!.pushed} records',
            ),
            _InfoRow(
              label: 'Downloaded',
              value: '${sync.lastResult!.pulled} records',
            ),
            _InfoRow(
              label: 'Remote deletions applied',
              value: '${sync.lastResult!.deleted} records',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _triggerSync(BuildContext context, CloudSyncMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final modeName = mode == CloudSyncMode.downloadOnly
        ? 'Download'
        : mode == CloudSyncMode.uploadOnly
        ? 'Upload'
        : 'Sync';

    try {
      final result = await context.read<CloudSyncProvider>().syncNow(
        mode: mode,
        isManual: true,
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$modeName complete: ${result.pushed} uploaded, ${result.pulled} downloaded.',
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
      padding: const EdgeInsets.symmetric(vertical: 9),
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

String _shortDeviceId(String value) {
  if (value.length <= 22) return value;
  return '${value.substring(0, 12)}…${value.substring(value.length - 8)}';
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

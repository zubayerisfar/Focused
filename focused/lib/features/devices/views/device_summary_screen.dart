import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../settings/providers/cloud_sync_provider.dart';
import '../../settings/services/cloud_sync_service.dart';
import '../../../core/theme/app_theme.dart';

class DeviceSummaryScreen extends StatefulWidget {
  const DeviceSummaryScreen({
    super.key,
    required this.device,
    this.isCurrent = false,
  });

  final CloudDevice device;
  final bool isCurrent;

  @override
  State<DeviceSummaryScreen> createState() => _DeviceSummaryScreenState();
}

class _DeviceSummaryScreenState extends State<DeviceSummaryScreen> {
  bool _isDeleting = false;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove device?'),
        content: Text(
          'Are you sure you want to remove "${widget.device.deviceName}" from your account? '
          'This device will need to sync again to be re-linked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await context.read<CloudSyncProvider>().deleteDevice(
          widget.device.deviceId,
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed device "${widget.device.deviceName}"'),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not remove device: $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.deviceName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!widget.isCurrent)
            IconButton(
              tooltip: 'Remove device',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _isDeleting ? null : () => _confirmDelete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _DeviceHeader(device: widget.device, isCurrent: widget.isCurrent),
          const SizedBox(height: 24),
          Text(
            'Device Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Device Name',
                  value: widget.device.deviceName,
                ),
                const Divider(height: 20),
                _InfoRow(
                  label: 'Platform',
                  value: widget.device.platform.toUpperCase(),
                ),
                const Divider(height: 20),
                _InfoRow(
                  label: 'Status',
                  value: widget.device.status.toUpperCase(),
                ),
                const Divider(height: 20),
                _InfoRow(
                  label: 'Device ID',
                  value: widget.device.deviceId,
                  mono: true,
                ),
                const Divider(height: 20),
                _InfoRow(
                  label: 'First Linked',
                  value: _formatDate(widget.device.createdAt),
                ),
                if (widget.device.lastSyncAt != null) ...[
                  const Divider(height: 20),
                  _InfoRow(
                    label: 'Last Synced',
                    value: _formatDate(widget.device.lastSyncAt!),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.isCurrent) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isDeleting ? null : () => _confirmDelete(context),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: const Text(
                'Remove This Device',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.device, required this.isCurrent});

  final CloudDevice device;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _deviceIcon(device.platform),
              color: AppTheme.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.deviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'This Device',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.platform.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

  IconData _deviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.smartphone_rounded;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

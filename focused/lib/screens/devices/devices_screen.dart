import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cloud_sync_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CloudSyncProvider>().refreshDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncProvider>();
    final currentId = sync.deviceId;
    final devices = sync.devices;
    CloudDevice? current;
    final others = <CloudDevice>[];
    for (final device in devices) {
      if (device.deviceId == currentId) {
        current = device;
      } else {
        others.add(device);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Devices',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh devices',
            onPressed: sync.isSyncing ? null : sync.refreshDevices,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sync.refreshDevices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Your devices',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Devices appear here after they sync with your Focused account.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
            if (sync.errorMessage != null) ...[
              const SizedBox(height: 14),
              _InfoCard(
                icon: Icons.error_outline_rounded,
                text: sync.errorMessage!,
              ),
            ],
            const SizedBox(height: 26),
            Text(
              'This device',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (current != null)
              _DeviceCard(device: current, current: true)
            else
              _PendingCurrentDeviceCard(
                deviceId: currentId,
                deviceName: sync.deviceName,
                newDevice: sync.isNewDevice,
              ),
            const SizedBox(height: 28),
            Text(
              'Other devices',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (others.isEmpty)
              const _InfoCard(
                icon: Icons.devices_other_rounded,
                text: 'No other synced devices are registered yet.',
              )
            else
              ...others.map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeviceCard(device: device),
                ),
              ),
            const SizedBox(height: 16),
            const _InfoCard(
              icon: Icons.privacy_tip_outlined,
              text:
                  'Workspace data can sync between devices. Raw screen-time, app-open and notification-event history stays local to the device where it was measured.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCurrentDeviceCard extends StatelessWidget {
  const _PendingCurrentDeviceCard({
    required this.deviceId,
    required this.deviceName,
    required this.newDevice,
  });

  final String? deviceId;
  final String? deviceName;
  final bool newDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DeviceIcon(platform: 'android'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName?.trim().isNotEmpty == true
                      ? deviceName!.trim()
                      : (newDevice ? 'New device detected' : 'Current installation'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  newDevice
                      ? 'Sync once to register this device and restore your workspace. Screen-time/app-open history is measured and stored locally from this Focused installation onward; notification history begins after notification access is enabled.'
                      : 'This installation has not been registered in Firestore yet.',
                  style: TextStyle(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (deviceId != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    _shortId(deviceId!),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, this.current = false});

  final CloudDevice device;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _DeviceIcon(platform: device.platform),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_platformLabel(device.platform)}${current ? ' • This device' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.lastSyncAt == null
                      ? 'Registered ${_relativeTime(device.createdAt)}'
                      : 'Last synced ${_relativeTime(device.lastSyncAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              device.status == 'active' ? 'Active' : device.status,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.platform});
  final String platform;

  @override
  Widget build(BuildContext context) {
    final normalized = platform.toLowerCase();
    final icon = normalized == 'windows'
        ? Icons.desktop_windows_rounded
        : normalized == 'macos'
            ? Icons.laptop_mac_rounded
            : normalized == 'ios'
                ? Icons.phone_iphone_rounded
                : Icons.smartphone_rounded;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.11),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppTheme.primaryBlue),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _platformLabel(String value) {
  switch (value.toLowerCase()) {
    case 'android':
      return 'Android';
    case 'windows':
      return 'Windows';
    case 'ios':
      return 'iOS';
    case 'macos':
      return 'macOS';
    case 'web':
      return 'Web';
    default:
      return value;
  }
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.isNegative || difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays == 1) return 'yesterday';
  if (difference.inDays < 30) return '${difference.inDays} days ago';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _shortId(String value) {
  if (value.length <= 24) return value;
  return '${value.substring(0, 12)}…${value.substring(value.length - 8)}';
}

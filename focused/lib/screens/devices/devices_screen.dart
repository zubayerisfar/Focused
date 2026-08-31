import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}
  
class _DevicesScreenState extends State<DevicesScreen> {
  bool _windowsDndEnabled = false;
  bool _tabletDndEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Devices',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Your devices',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 6),

          Text(
            'Manage devices connected to your Focused account.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.52),
            ),
          ),

          const SizedBox(height: 26),

          Text(
            'This device',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          const _CurrentDeviceCard(),

          const SizedBox(height: 28),

          Text(
            'Other devices',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          _RemoteDeviceCard(
            icon: Icons.desktop_windows_rounded,
            name: 'My Windows PC',
            platform: 'Windows',
            lastSeen: 'Last seen 4 min ago',
            dndEnabled: _windowsDndEnabled,
            onDndChanged: (value) {
              setState(() {
                _windowsDndEnabled = value;
              });
            },
          ),

          const SizedBox(height: 12),

          _RemoteDeviceCard(
            icon: Icons.tablet_android_rounded,
            name: 'Android Tablet',
            platform: 'Android',
            lastSeen: 'Last seen yesterday',
            dndEnabled: _tabletDndEnabled,
            onDndChanged: (value) {
              setState(() {
                _tabletDndEnabled = value;
              });
            },
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Later, changing DND here will send a command through Firebase to the selected device.',
                    style: TextStyle(
                      height: 1.45,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.66),
                    ),
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

class _CurrentDeviceCard extends StatelessWidget {
  const _CurrentDeviceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              color: AppTheme.primaryBlue,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'moto g96 5G',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text('Android • This device', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF34B27B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF34B27B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteDeviceCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String platform;
  final String lastSeen;
  final bool dndEnabled;
  final ValueChanged<bool> onDndChanged;

  const _RemoteDeviceCard({
    required this.icon,
    required this.name,
    required this.platform,
    required this.lastSeen,
    required this.dndEnabled,
    required this.onDndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primaryBlue),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      platform,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.52),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastSeen,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.42),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: dndEnabled,
            onChanged: onDndChanged,
            secondary: Icon(
              dndEnabled
                  ? Icons.do_not_disturb_on_rounded
                  : Icons.do_not_disturb_off_outlined,
            ),
            title: const Text(
              'Do Not Disturb',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(dndEnabled ? 'Enabled' : 'Disabled'),
          ),
        ],
      ),
    );
  }
}

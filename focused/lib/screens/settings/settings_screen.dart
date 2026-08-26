import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              const _ProfileRow(),
              const Divider(height: 1),
              _NavigationSetting(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'Return to login screen',
                onTap: () {
                  context.go('/login');
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SettingsSection(
            title: 'Appearance',
            children: [
              _ThemeOption(
                title: 'System',
                subtitle: 'Use your device theme',
                mode: ThemeMode.system,
                currentMode: themeProvider.themeMode,
              ),
              _ThemeOption(
                title: 'Light',
                subtitle: 'Always use light mode',
                mode: ThemeMode.light,
                currentMode: themeProvider.themeMode,
              ),
              _ThemeOption(
                title: 'Dark',
                subtitle: 'Always use dark mode',
                mode: ThemeMode.dark,
                currentMode: themeProvider.themeMode,
              ),
            ],
          ),

          const SizedBox(height: 20),

          const _SettingsSection(
            title: 'Focus',
            children: [
              _SimpleSetting(
                icon: Icons.timer_outlined,
                title: 'Default focus block',
                value: '50 min',
              ),
              _SimpleSetting(
                icon: Icons.free_breakfast_outlined,
                title: 'Default break',
                value: '10 min',
              ),
            ],
          ),

          const SizedBox(height: 20),

          const _SettingsSection(
            title: 'Calendar',
            children: [
              _SimpleSetting(
                icon: Icons.calendar_month_outlined,
                title: 'Google Calendar',
                value: 'Not connected',
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SettingsSection(
            title: 'Devices',
            children: [
              _NavigationSetting(
                icon: Icons.devices_outlined,
                title: 'My Devices',
                subtitle: 'Manage connected devices and DND',
                onTap: () {
                  context.push('/devices');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(Icons.person_rounded)),
      title: Text(
        'Focused User',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('Google account will appear here'),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final ThemeMode mode;
  final ThemeMode currentMode;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Radio<ThemeMode>(
        value: mode,
        groupValue: currentMode,
        onChanged: (value) {
          if (value != null) {
            context.read<ThemeProvider>().setThemeMode(value);
          }
        },
      ),
      onTap: () {
        context.read<ThemeProvider>().setThemeMode(mode);
      },
    );
  }
}

class _NavigationSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SimpleSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SimpleSetting({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

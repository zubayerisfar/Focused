import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/usage_access_status.dart';
import '../../providers/task_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/usage_provider.dart';
import '../../providers/user_profile_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final profileProvider = context.watch<UserProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          _ProfileHeader(
            name: profileProvider.profile.displayName,
            email: profileProvider.profile.email,
            onTap: () => _editProfile(context),
          ),
          const SizedBox(height: 14),
          _SectionLabel('Permissions & access'),
          _SettingsTile(
            icon: Icons.query_stats_rounded,
            title: 'App usage access',
            subtitle: _usageStatusText(usageProvider.accessStatus),
            trailing: _StatusDot(
              active:
                  usageProvider.accessStatus == UsageAccessStatus.granted,
            ),
            onTap: () => context.push('/wellbeing/permission'),
          ),
          _SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Test notification permission and delivery',
            onTap: () async {
              final success = await context
                  .read<TaskProvider>()
                  .sendTestNotification();

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Test notification sent.'
                        : 'Notifications are unavailable. Check Android settings.',
                  ),
                ),
              );
            },
          ),
          const _SectionDivider(),
          _SectionLabel('Personal information'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: _profileSubtitle(
              profileProvider.profile.displayName,
              profileProvider.profile.email,
            ),
            onTap: () => _editProfile(context),
          ),
          const _SectionDivider(),
          _SectionLabel('Personalization'),
          _AppearanceTile(),
          const _SectionDivider(),
          _SectionLabel('Account'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Return to the sign-in screen',
            onTap: () => context.go('/login'),
          ),
          const _DisabledAccountTile(
            icon: Icons.pause_circle_outline_rounded,
            title: 'Deactivate account',
            subtitle: 'Available after cloud account sync is connected',
          ),
          const _DisabledAccountTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account',
            subtitle: 'Available after cloud account sync is connected',
            destructive: true,
          ),
        ],
      ),
    );
  }

  static String _usageStatusText(UsageAccessStatus status) {
    switch (status) {
      case UsageAccessStatus.granted:
        return 'Allowed';
      case UsageAccessStatus.denied:
        return 'Permission needed';
      case UsageAccessStatus.unsupported:
        return 'Android only';
      case UsageAccessStatus.error:
        return 'Could not read permission';
      case UsageAccessStatus.checking:
        return 'Checking…';
      case UsageAccessStatus.unknown:
        return 'Not checked yet';
    }
  }

  static String _profileSubtitle(String name, String email) {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }

    final trimmedName = name.trim();
    return trimmedName.isEmpty ? 'Local profile' : trimmedName;
  }

  static Future<void> _editProfile(BuildContext context) async {
    final provider = context.read<UserProfileProvider>();

    final nameController = TextEditingController(
      text: provider.profile.displayName,
    );

    final emailController = TextEditingController(
      text: provider.profile.email,
    );

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            2,
            18,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal information',
                style:
                    Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText:
                      'Stored locally until account sync is implemented.',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (save == true) {
      await provider.updateProfile(
        displayName: nameController.text,
        email: emailController.text,
      );
    }

    nameController.dispose();
    emailController.dispose();
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        name.trim().isEmpty ? 'Focused user' : name.trim();
    final subtitle =
        email.trim().isEmpty ? 'Local profile' : email.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                displayName[0].toUpperCase(),
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: onTap,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: SizedBox(
        width: 38,
        height: 38,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing:
          trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();

    return _SettingsTile(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      subtitle: _themeLabel(provider.themeMode),
      onTap: () => _showAppearanceSheet(context),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  static Future<void> _showAppearanceSheet(
    BuildContext context,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .headlineMedium,
                ),
                const SizedBox(height: 12),
                ...ThemeMode.values.map(
                  (mode) => RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    value: mode,
                    groupValue: sheetContext
                        .watch<ThemeProvider>()
                        .themeMode,
                    title: Text(_themeLabel(mode)),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      sheetContext
                          .read<ThemeProvider>()
                          .setThemeMode(value);

                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? const Color(0xFF35B779)
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}

class _DisabledAccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;

  const _DisabledAccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error.withOpacity(0.62)
        : Theme.of(context).disabledColor;

    return ListTile(
      enabled: false,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      subtitle: Text(subtitle),
    );
  }
}

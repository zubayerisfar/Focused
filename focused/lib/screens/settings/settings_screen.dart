import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/usage_access_status.dart';
import '../../providers/account_provider.dart';
import '../../providers/private_sync_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/usage_provider.dart';
import '../../providers/user_profile_provider.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final account = context.watch<AccountProvider>();
    final privateSync = context.watch<PrivateSyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 110),
        children: [
          _ProfileHeader(
            name: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
            providerText: account.signedInWithGoogle
                ? 'Google account'
                : 'Email account',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            title: 'Permissions & access',
            subtitle: 'Usage access and notifications',
            icon: const FaIcon(FontAwesomeIcons.shieldHalved, size: 18),
            initiallyExpanded: true,
            children: [
              _SettingsTile(
                icon: Icons.query_stats_rounded,
                title: 'App usage access',
                subtitle: _usageStatusText(usageProvider.accessStatus),
                trailing: _StatusDot(
                  active: usageProvider.accessStatus == UsageAccessStatus.granted,
                ),
                onTap: () => context.push('/wellbeing/permission'),
              ),
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Test permission and delivery',
                onTap: () async {
                  final success = await context
                      .read<TaskProvider>()
                      .sendTestNotification();
                  if (!context.mounted) return;
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
            ],
          ),
          _SettingsSection(
            title: 'Account',
            subtitle: 'Profile and email',
            icon: const FaIcon(FontAwesomeIcons.user, size: 18),
            children: [
              _SettingsTile(
                icon: account.signedInWithGoogle
                    ? Icons.account_circle_outlined
                    : Icons.alternate_email_rounded,
                title: account.displayName,
                subtitle: account.email,
                onTap: () => _editProfile(context),
              ),
              if (!account.signedInWithGoogle)
                _SettingsTile(
                  icon: account.emailVerified
                      ? Icons.verified_rounded
                      : Icons.mark_email_unread_outlined,
                  title: 'Email verification',
                  subtitle: account.emailVerified ? 'Verified' : 'Not verified yet',
                  onTap: () => _handleEmailVerification(context),
                ),
            ],
          ),
          _SettingsSection(
            title: 'Privacy & sync',
            subtitle: privateSync.statusLabel,
            icon: const FaIcon(FontAwesomeIcons.lock, size: 18),
            children: [
              _SettingsTile(
                icon: privateSync.isReady ? Icons.lock_rounded : Icons.cloud_outlined,
                title: 'Encrypted sync',
                subtitle: privateSync.statusLabel,
                trailing: _StatusDot(active: privateSync.isReady),
                onTap: () => context.push('/settings/private-sync'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Personalization',
            subtitle: 'Theme and appearance',
            icon: const FaIcon(FontAwesomeIcons.palette, size: 18),
            children: const [
              _AppearanceTile(),
            ],
          ),
          _SettingsSection(
            title: 'Session & account actions',
            subtitle: 'Sign out or manage the account',
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: privateSync.cloudConfigured
                    ? 'Remove this device’s local private key and sign out'
                    : 'Sign out of Firebase on this device',
                onTap: () => _signOut(context),
              ),
              const _DisabledAccountTile(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Deactivate account',
                subtitle: 'Available after encrypted cloud sync is connected',
              ),
              const _DisabledAccountTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle: 'Available after encrypted cloud sync is connected',
                destructive: true,
              ),
            ],
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

  static Future<void> _handleEmailVerification(BuildContext context) async {
    final account = context.read<AccountProvider>();
    if (account.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your email is already verified.')),
      );
      return;
    }

    try {
      await account.resendVerificationEmail();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. After verifying, reopen Settings.',
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> _editProfile(BuildContext context) async {
    final account = context.read<AccountProvider>();
    final localProfile = context.read<UserProfileProvider>();
    final nameController = TextEditingController(text: account.displayName);

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
                'Profile',
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Managed by Firebase Authentication.',
                ),
                child: Text(account.email),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save display name'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (save == true && nameController.text.trim().isNotEmpty) {
      await account.updateDisplayName(nameController.text);
      await localProfile.updateProfile(
        displayName: account.displayName,
        email: account.email,
      );
    }
    nameController.dispose();
  }

  static Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: Text(
            context.read<PrivateSyncProvider>().cloudConfigured
                ? 'This signs you out and removes the Focused private key '
                    'stored on this device. Your local productivity data is '
                    'not deleted. Make sure you saved the private key first.'
                : 'This signs you out of your Focused account. '
                    'Your existing local productivity data is not deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<PrivateSyncProvider>().forgetLocalKeyForSignOut();
    if (!context.mounted) return;
    await context.read<AccountProvider>().signOut();
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Widget icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        leading: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: scheme.primary),
              child: icon,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.providerText,
    required this.onTap,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final String providerText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Focused user' : name.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 31,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
              child: photoUrl == null
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    providerText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w400),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

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

  static Future<void> _showAppearanceSheet(BuildContext context) {
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
                  style: Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ...ThemeMode.values.map(
                  (mode) => RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    value: mode,
                    groupValue: sheetContext.watch<ThemeProvider>().themeMode,
                    title: Text(_themeLabel(mode)),
                    onChanged: (value) {
                      if (value == null) return;
                      sheetContext.read<ThemeProvider>().setThemeMode(value);
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
  const _StatusDot({required this.active});
  final bool active;

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

class _DisabledAccountTile extends StatelessWidget {
  const _DisabledAccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error.withOpacity(0.62)
        : Theme.of(context).disabledColor;
    return ListTile(
      enabled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: Text(subtitle),
    );
  }
}

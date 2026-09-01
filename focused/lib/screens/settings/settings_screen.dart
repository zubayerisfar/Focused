import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/usage_access_status.dart';
import '../../providers/account_provider.dart';
import '../../providers/cloud_sync_provider.dart';
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
    final cloudSync = context.watch<CloudSyncProvider>();
    final profile = context.watch<UserProfileProvider>().profile;

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
                icon: FontAwesomeIcons.chartSimple,
                title: 'App usage access',
                subtitle: _usageStatusText(usageProvider.accessStatus),
                trailing: _StatusDot(
                  active:
                      usageProvider.accessStatus == UsageAccessStatus.granted,
                ),
                onTap: () => context.push('/wellbeing/permission'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Account',
            subtitle: 'Profile, birthday and nationality',
            icon: const FaIcon(FontAwesomeIcons.user, size: 18),
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.userPen,
                title: account.displayName,
                subtitle: account.email,
                onTap: () => _editProfile(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.flag,
                title: 'Nationality',
                subtitle: profile.nationality.trim().isEmpty
                    ? 'Not added'
                    : profile.nationality,
                onTap: () => _editProfile(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.cakeCandles,
                title: 'Birthday',
                subtitle: profile.birthday == null
                    ? 'Not added'
                    : DateFormat('MMMM d').format(profile.birthday!),
                onTap: () => _editProfile(context),
              ),
              if (!account.signedInWithGoogle)
                _SettingsTile(
                  icon: account.emailVerified
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.envelope,
                  title: 'Email verification',
                  subtitle: account.emailVerified
                      ? 'Verified'
                      : 'Not verified yet',
                  onTap: () => _handleEmailVerification(context),
                ),
            ],
          ),
          _SettingsSection(
            title: 'Session & account actions',
            subtitle: 'Manage your Focused account',
            icon: const FaIcon(FontAwesomeIcons.userShield, size: 18),
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.pause,
                title: 'Deactivate account',
                subtitle: 'Pause your account for 24 hours',
                onTap: () => context.push('/settings/deactivate-account'),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.trash,
                title: 'Delete account',
                subtitle: 'Permanently remove your account',
                onTap: () => context.push('/settings/delete-account'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Cloud Sync',
            subtitle: cloudSync.statusLabel,
            icon: const FaIcon(FontAwesomeIcons.cloudArrowUp, size: 18),
            children: [
              _SettingsTile(
                icon: cloudSync.isSyncing
                    ? FontAwesomeIcons.arrowsRotate
                    : FontAwesomeIcons.cloudArrowUp,
                title: 'Workspace sync',
                subtitle: cloudSync.statusLabel,
                trailing: _StatusDot(
                  active:
                      cloudSync.lastSyncAt != null &&
                      cloudSync.errorMessage == null,
                ),
                onTap: () => context.push('/settings/cloud-sync'),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.laptop,
                title: 'My devices',
                subtitle: cloudSync.devices.isEmpty
                    ? 'View registered installations'
                    : '${cloudSync.devices.length} registered',
                onTap: () => context.push('/devices'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Personalization',
            subtitle: 'Theme and appearance',
            icon: const FaIcon(FontAwesomeIcons.palette, size: 18),
            children: const [_AppearanceTile()],
          ),
          _SettingsSection(
            title: 'Session & account actions',
            subtitle: 'Sign out or manage the account',
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.rightFromBracket,
                title: 'Sign out',
                subtitle: 'Sign out on this device',
                onTap: () => _signOut(context),
              ),
              const _DisabledAccountTile(
                icon: FontAwesomeIcons.circlePause,
                title: 'Deactivate account',
                subtitle: 'Not implemented yet',
              ),
              const _DisabledAccountTile(
                icon: FontAwesomeIcons.trash,
                title: 'Delete account',
                subtitle: 'Not implemented yet',
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
    final current = localProfile.profile;
    final nameController = TextEditingController(text: account.displayName);
    final nationalityController = TextEditingController(
      text: current.nationality,
    );
    DateTime? selectedBirthday = current.birthday;

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                2,
                18,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile information',
                      style: Theme.of(sheetContext).textTheme.headlineMedium,
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
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Email'),
                      child: Text(account.email),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nationalityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nationality',
                        hintText: 'Optional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      child: ListTile(
                        leading: const FaIcon(
                          FontAwesomeIcons.cakeCandles,
                          size: 18,
                        ),
                        title: const Text('Birthday'),
                        subtitle: Text(
                          selectedBirthday == null
                              ? 'Optional'
                              : DateFormat(
                                  'MMMM d, yyyy',
                                ).format(selectedBirthday!),
                        ),
                        trailing: selectedBirthday == null
                            ? const Icon(Icons.chevron_right_rounded)
                            : IconButton(
                                tooltip: 'Remove birthday',
                                onPressed: () {
                                  setSheetState(() => selectedBirthday = null);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate:
                                selectedBirthday ??
                                DateTime(now.year - 20, now.month, now.day),
                            firstDate: DateTime(now.year - 120),
                            lastDate: now,
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedBirthday = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedBirthday == null
                          ? 'Add a birthday if you want Focused to wish you happy birthday.'
                          : 'Focused will schedule a yearly birthday notification at 9:00 AM if notification permission is allowed.',
                      style: TextStyle(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Save profile'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (save == true && nameController.text.trim().isNotEmpty) {
      await account.updateDisplayName(nameController.text);
      await localProfile.updateProfile(
        displayName: account.displayName,
        email: account.email,
        nationality: nationalityController.text.trim(),
        birthday: selectedBirthday,
        clearBirthday: selectedBirthday == null,
      );
    }
    nameController.dispose();
    nationalityController.dispose();
  }

  static Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'This signs you out of your Focused account. Your existing local productivity data and local Digital Wellbeing history are not deleted.',
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
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
    required this.onTap,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Text(
                        _initials(name),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
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
    this.trailing,
    this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FaIcon(icon, size: 18),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green : Theme.of(context).colorScheme.outline,
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

  final FaIconData icon;
  final String title;
  final String subtitle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      enabled: false,
      leading: FaIcon(icon, size: 18, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ListTile(
      leading: const FaIcon(FontAwesomeIcons.circleHalfStroke, size: 18),
      title: const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
      trailing: DropdownButton<ThemeMode>(
        value: theme.themeMode,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) {
            context.read<ThemeProvider>().setThemeMode(value);
          }
        },
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'F';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

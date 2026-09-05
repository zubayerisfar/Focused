import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../wellbeing/models/usage_access_status.dart';
import '../../auth/providers/account_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../wellbeing/providers/usage_provider.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../friends/providers/friends_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../../wellbeing/services/app_usage_summary_service.dart';
import '../../../core/services/notification_access_service.dart';
import '../../tasks/services/task_notification_service.dart';
import 'deactivate_account_sheet.dart';
import 'delete_account_dialog.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  Future<void> _openAppNotificationSettings(BuildContext context) async {
    final service = NotificationAccessService();
    if (!service.isSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings are available on Android.'),
          ),
        );
      }
      return;
    }

    try {
      await service.openAppNotificationSettings();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Android notification settings: $error'),
        ),
      );
    }
  }

  Future<void> _openDailySummariesDialog(BuildContext context) async {
    const service = AppUsageSummaryService();
    final isEnabled = await service.isEnabled();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        var enabled = isEnabled;
        return StatefulBuilder(
          builder: (context, setState) {
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Daily App Summaries',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Get two quick notifications each day showing how much time you spent on your phone.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFB300,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.wb_sunny_rounded,
                                color: Color(0xFFFFB300),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '5:00 PM — Afternoon check',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Screen time so far today and your most-used app.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.nightlight_round,
                                color: Color(0xFF6366F1),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '11:00 PM — Night wrap-up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Total screen time for the whole day before bedtime.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Send daily notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        enabled
                            ? 'You will receive updates at 5:00 PM and 11:00 PM'
                            : 'Notifications are turned off',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      value: enabled,
                      onChanged: (val) async {
                        setState(() => enabled = val);
                        await service.setEnabled(val);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openNotificationPreferencesDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer<NotificationPreferencesProvider>(
          builder: (context, notifPrefs, _) {
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notification Preferences',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Customize alerts for social events and reminders',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Core task and habit reminders remain always active. You can customize the social and occasional notifications below:',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const FaIcon(
                        FontAwesomeIcons.userPlus,
                        size: 18,
                      ),
                      title: const Text(
                        'Follower alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Receive an alert with user icon when someone follows you',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: notifPrefs.followerAlerts,
                      onChanged: (val) => notifPrefs.setFollowerAlerts(val),
                    ),
                    const Divider(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const FaIcon(FontAwesomeIcons.users, size: 18),
                      title: const Text(
                        'Squad group invites',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Get notified when friends invite you to join a new Task Squad',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: notifPrefs.squadInvites,
                      onChanged: (val) => notifPrefs.setSquadInvites(val),
                    ),
                    const Divider(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const FaIcon(
                        FontAwesomeIcons.handPointRight,
                        size: 18,
                      ),
                      title: const Text(
                        'Friend nudges & EXP gifts',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Alerts for task reminders and EXP boosts sent by your friends',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: notifPrefs.friendNudgesAndGifts,
                      onChanged: (val) =>
                          notifPrefs.setFriendNudgesAndGifts(val),
                    ),
                    const Divider(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const FaIcon(
                        FontAwesomeIcons.flagCheckered,
                        size: 18,
                      ),
                      title: const Text(
                        'Partner task completions',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        '"Your friend finished their task, now it\'s your turn!"',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: notifPrefs.partnerCompletions,
                      onChanged: (val) => notifPrefs.setPartnerCompletions(val),
                    ),
                    const Divider(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const FaIcon(
                        FontAwesomeIcons.solidClock,
                        size: 18,
                      ),
                      title: const Text(
                        'Occasional daily check-in',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        'Gentle reflection reminder (${notifPrefs.occasionalTime.format(context)})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: notifPrefs.occasionalReminders,
                      onChanged: (val) async {
                        await notifPrefs.setOccasionalReminders(val);
                        final taskNotif = TaskNotificationService();
                        if (val) {
                          await taskNotif.scheduleOccasionalReminder(
                            hour: notifPrefs.occasionalTime.hour,
                            minute: notifPrefs.occasionalTime.minute,
                          );
                        } else {
                          await taskNotif.cancelOccasionalReminder();
                        }
                      },
                    ),
                    if (notifPrefs.occasionalReminders) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 18),
                        label: Text(
                          'Change time: ${notifPrefs.occasionalTime.format(context)}',
                        ),
                        onPressed: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: notifPrefs.occasionalTime,
                          );
                          if (selected != null) {
                            await notifPrefs.setOccasionalTime(selected);
                            final taskNotif = TaskNotificationService();
                            await taskNotif.scheduleOccasionalReminder(
                              hour: selected.hour,
                              minute: selected.minute,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final account = context.watch<AccountProvider>();
    final cloudSync = context.watch<CloudSyncProvider>();
    final profile = context.watch<UserProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
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
              _SettingsTile(
                icon: FontAwesomeIcons.bell,
                title: 'Notification permission',
                subtitle: 'Allow reminders and focus notifications',
                onTap: () => _openAppNotificationSettings(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.sliders,
                title: 'Notification preferences',
                subtitle: 'Social alerts, squad invites & occasional reminders',
                onTap: () => _openNotificationPreferencesDialog(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.clockRotateLeft,
                title: 'Daily App Summaries',
                subtitle: '5:00 PM snapshot & 11:00 PM wrap-up',
                onTap: () => _openDailySummariesDialog(context),
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
                onTap: () => editProfile(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.at,
                title: 'Username',
                subtitle: profile.handle,
                onTap: () => editProfile(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.flag,
                title: 'Nationality',
                subtitle: profile.nationality.trim().isEmpty
                    ? 'Not added'
                    : profile.nationality,
                onTap: () => editProfile(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.cakeCandles,
                title: 'Birthday',
                subtitle: profile.birthday == null
                    ? 'Not added'
                    : DateFormat('MMMM d').format(profile.birthday!),
                onTap: () => editProfile(context),
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
              _SettingsTile(
                icon: FontAwesomeIcons.circlePause,
                title: 'Deactivate account',
                subtitle: 'Pause account & sign out',
                onTap: () => DeactivateAccountSheet.show(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.trash,
                title: 'Delete account',
                subtitle: 'Permanently wipe account & data',
                onTap: () => DeleteAccountDialog.show(context),
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

  static Future<void> editProfile(BuildContext context) async {
    final account = context.read<AccountProvider>();
    final localProfile = context.read<UserProfileProvider>();
    final current = localProfile.profile;
    final resolvedUsername =
        (current.username.trim().isNotEmpty &&
            current.username.trim().toLowerCase() != 'focuseduser' &&
            current.username.trim().toLowerCase() != 'focused_user')
        ? current.username.trim()
        : UserProfile.defaultUsernameFromEmail(
            account.email,
            fallback: current.handle.replaceFirst('@', ''),
          );
    final nameController = TextEditingController(text: account.displayName);
    final usernameController = TextEditingController(text: resolvedUsername);
    final nationalityController = TextEditingController(
      text: current.nationality,
    );
    DateTime? selectedBirthday = current.birthday;
    String? usernameError;
    bool isCheckingUsername = false;

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
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username (handle)',
                        prefixText: '@ ',
                        errorText: usernameError,
                        helperText: 'Unique handle used by friends to find you',
                      ),
                      onChanged: (_) {
                        if (usernameError != null) {
                          setSheetState(() => usernameError = null);
                        }
                      },
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
                        onPressed: isCheckingUsername
                            ? null
                            : () async {
                                final clean = usernameController.text
                                    .trim()
                                    .replaceAll('@', '');
                                if (clean.isNotEmpty &&
                                    clean != current.username) {
                                  if (clean.length < 3) {
                                    setSheetState(
                                      () => usernameError =
                                          'Username must be at least 3 characters',
                                    );
                                    return;
                                  }
                                  final friendsProvider = sheetContext
                                      .read<FriendsProvider>();
                                  setSheetState(
                                    () => isCheckingUsername = true,
                                  );
                                  final isAvailable = await friendsProvider
                                      .checkUsernameAvailability(clean);
                                  if (!sheetContext.mounted) return;
                                  setSheetState(
                                    () => isCheckingUsername = false,
                                  );
                                  if (!isAvailable) {
                                    setSheetState(
                                      () => usernameError =
                                          'Username @$clean is already taken',
                                    );
                                    return;
                                  }
                                }
                                Navigator.pop(sheetContext, true);
                              },
                        child: isCheckingUsername
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save profile'),
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
      final cleanUsername = usernameController.text.trim().replaceAll('@', '');
      await account.updateDisplayName(nameController.text);
      if (cleanUsername.isNotEmpty &&
          cleanUsername != current.username &&
          account.isSignedIn &&
          context.mounted) {
        await context.read<FriendsProvider>().updateUsername(
          oldUsername: current.username,
          newUsername: cleanUsername,
        );
      }
      await localProfile.updateProfile(
        displayName: account.displayName,
        email: account.email,
        username: cleanUsername.isNotEmpty ? cleanUsername : current.username,
        nationality: nationalityController.text.trim(),
        birthday: selectedBirthday,
        clearBirthday: selectedBirthday == null,
      );
      if (account.isSignedIn && context.mounted) {
        context.read<FriendsProvider>().initForUser(
          account.user!.uid,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
      }
    }
    nameController.dispose();
    usernameController.dispose();
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: FaIcon(icon, size: 18),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
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

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: const FaIcon(FontAwesomeIcons.circleHalfStroke, size: 18),
        title: const Text(
          'Theme',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
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

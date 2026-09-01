import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/task_provider.dart';
import '../../services/notification_access_service.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen>
    with WidgetsBindingObserver {
  final NotificationAccessService _settingsService =
      NotificationAccessService();
  bool? _enabled;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _busy = true);
    final value = await context.read<TaskProvider>().notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _busy = false;
    });
  }

  Future<void> _request() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final granted = await context
          .read<TaskProvider>()
          .requestNotificationPermission();
      if (!mounted) return;
      setState(() {
        _enabled = granted;
        _busy = false;
      });

      // If Android does not show the runtime prompt (for example after the
      // user has denied it repeatedly), take the user to Focused's system
      // notification settings so the permission can still be changed.
      if (!granted) {
        await _settingsService.openAppNotificationSettings();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openAndroidSettings() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await _settingsService.openAppNotificationSettings();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = _enabled == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification permission')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: enabled
                  ? scheme.primaryContainer
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: enabled
                    ? scheme.primary.withOpacity(0.45)
                    : scheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                FaIcon(
                  enabled
                      ? FontAwesomeIcons.solidBell
                      : FontAwesomeIcons.bellSlash,
                  size: 40,
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  enabled
                      ? 'Notifications are allowed'
                      : 'Notifications need permission',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Focused uses notifications for task reminders, habit reminders, focus transitions, and birthday reminders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(FontAwesomeIcons.bell, size: 16),
            label: Text(
              enabled
                  ? 'Check Android permission again'
                  : 'Allow notifications',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openAndroidSettings,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Open Android notification settings'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 12),
          Text(
            'Notification permission lets Focused send task reminders, habit reminders and focus alerts.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}

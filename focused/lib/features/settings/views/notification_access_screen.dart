import 'package:flutter/material.dart';

import '../../../services/notification_access_service.dart';

class NotificationAccessScreen extends StatefulWidget {
  const NotificationAccessScreen({super.key});

  @override
  State<NotificationAccessScreen> createState() =>
      _NotificationAccessScreenState();
}

class _NotificationAccessScreenState extends State<NotificationAccessScreen>
    with WidgetsBindingObserver {
  final NotificationAccessService _service = NotificationAccessService();
  bool _checking = true;
  bool _granted = false;
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
    if (!mounted) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final granted = await _service.hasAccess();
      if (!mounted) return;
      setState(() {
        _granted = granted;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openSettings() async {
    try {
      await _service.openSettings();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Access',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
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
                    Icon(
                      _granted
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: _granted
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _checking
                            ? 'Checking…'
                            : _granted
                            ? 'Notification access allowed'
                            : 'Notification access needed',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This is different from normal notification permission. '
                  'It lets Focused count how many notifications other apps post.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Focused stores only the app package, timestamp and notification key for deduplication. '
                  'It does not store message text, sender names, notification bodies or images.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _checking ? null : _openSettings,
            icon: const Icon(Icons.settings_rounded),
            label: Text(
              _granted
                  ? 'Review Android notification access'
                  : 'Open Android notification access',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _checking ? null : _refresh,
            child: const Text('Check again'),
          ),
        ],
      ),
    );
  }
}

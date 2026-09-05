import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/account_provider.dart';
import '../../../core/theme/app_theme.dart';

class DeactivateAccountSheet extends StatefulWidget {
  const DeactivateAccountSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const DeactivateAccountSheet(),
    );
  }

  @override
  State<DeactivateAccountSheet> createState() => _DeactivateAccountSheetState();
}

class _DeactivateAccountSheetState extends State<DeactivateAccountSheet> {
  static const List<String> _presetReasons = [
    'Taking a temporary break from tracking',
    'Switching to another productivity app',
    'Too many notifications or alerts',
    'Privacy or digital wellbeing concerns',
    'Other reason',
  ];

  String _selectedReason = _presetReasons.first;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleDeactivate() async {
    final reason = _selectedReason == 'Other reason'
        ? _customReasonController.text.trim().isEmpty
              ? 'Other reason'
              : _customReasonController.text.trim()
        : _selectedReason;

    setState(() => _isProcessing = true);

    try {
      await context.read<AccountProvider>().deactivateAccount(reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account has been deactivated. Contact support.focused@gmail.com to reactivate.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not deactivate account: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.pause_circle_outline_rounded,
                    color: AppTheme.warning,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deactivate Account',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pause your account & sign out',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens when you deactivate?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• You will be signed out on this device.\n'
                    '• Your workspace cloud sync will be paused.\n'
                    '• To reactivate your account in the future, you must reach out to support.focused@gmail.com.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Why are you leaving?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ..._presetReasons.map(
              (reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                value: reason,
                groupValue: _selectedReason,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: _isProcessing
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedReason = value);
                        }
                      },
              ),
            ),
            if (_selectedReason == 'Other reason') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customReasonController,
                maxLines: 2,
                enabled: !_isProcessing,
                decoration: const InputDecoration(
                  labelText: 'Tell us more (optional)',
                  hintText: 'Share your feedback…',
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isProcessing ? null : _handleDeactivate,
                    child: Text(_isProcessing ? 'Deactivating…' : 'Deactivate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

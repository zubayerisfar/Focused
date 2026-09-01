import 'package:flutter/material.dart';

class PermissionExplanationScreen extends StatelessWidget {
  final String title;
  final String permissionName;
  final VoidCallback onContinue;

  const PermissionExplanationScreen({
    super.key,
    required this.title,
    required this.permissionName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.privacy_tip_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 18),
          Text(
            'Your privacy matters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Focused uses $permissionName only to provide productivity insights.',
          ),
          const SizedBox(height: 20),
          _item(context, '✓ Calculates usage locally on your device'),
          _item(
            context,
            '✓ Helps you understand focus and distraction patterns',
          ),
          _item(
            context,
            '✓ Syncs only workspace data such as tasks, habits and focus sessions',
          ),
          const SizedBox(height: 18),
          Text(
            'Focused does not:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _item(context, '✗ Upload raw screen-time history'),
          _item(context, '✗ Read messages, emails or private content'),
          _item(context, '✗ Sell or share personal data'),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Continue to permission'),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text),
    );
  }
}

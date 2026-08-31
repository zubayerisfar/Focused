import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/private_sync_provider.dart';

class PrivateSyncScreen extends StatelessWidget {
  const PrivateSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync =
        context.watch<PrivateSyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy & Sync',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh:
            context.read<PrivateSyncProvider>().refresh,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
                18,
                14,
                18,
                36,
              ),
          children: [
            _StatusCard(sync: sync),
            const SizedBox(height: 18),
            if (sync.state ==
                PrivateSyncState.localOnly)
              _LocalOnlyActions(sync: sync),
            if (sync.state ==
                    PrivateSyncState.keyRequired ||
                sync.state ==
                    PrivateSyncState.keyChanged)
              _KeyRequiredActions(sync: sync),
            if (sync.state ==
                    PrivateSyncState.ready ||
                sync.state ==
                    PrivateSyncState.syncing)
              _ReadyActions(sync: sync),
            if (sync.state ==
                PrivateSyncState.remoteChanged)
              _RemoteChangedActions(sync: sync),
            if (sync.state ==
                PrivateSyncState.error)
              _ErrorActions(sync: sync),
            const SizedBox(height: 26),
            const _PrivacyExplanation(),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sync});

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    final active =
        sync.state == PrivateSyncState.ready ||
        sync.state == PrivateSyncState.syncing;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: active
              ? scheme.primary.withOpacity(0.45)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              active
                  ? Icons.lock_rounded
                  : Icons.shield_outlined,
              color: active
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  sync.statusLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  _statusDescription(sync),
                  style: TextStyle(
                    color:
                        scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (sync.cloudKeyVersion != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Key version ${sync.cloudKeyVersion}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (sync.isBusy)
            const Padding(
              padding: EdgeInsets.only(
                top: 5,
              ),
              child: SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusDescription(
    PrivateSyncProvider sync,
  ) {
    switch (sync.state) {
      case PrivateSyncState.checking:
        return 'Checking this account’s encrypted sync state.';
      case PrivateSyncState.localOnly:
        return 'Your Focused productivity data stays on this device. '
            'Nothing is uploaded until you enable private sync.';
      case PrivateSyncState.ready:
        return 'Focused-owned data is encrypted on this device before '
            'its cloud copy is uploaded.';
      case PrivateSyncState.keyRequired:
        return 'This account already has encrypted cloud data. Enter its '
            'Focused private key to authorize this device.';
      case PrivateSyncState.keyChanged:
        return 'The private key was rotated on another device. Enter the '
            'new key before this device can sync again.';
      case PrivateSyncState.syncing:
        return 'Encrypting local Focused data and updating the cloud copy.';
      case PrivateSyncState.remoteChanged:
        return 'Another device changed the cloud snapshot. Focused stopped '
            'this device from overwriting it.';
      case PrivateSyncState.error:
        return sync.errorMessage ??
            'Private sync needs attention.';
    }
  }
}

class _LocalOnlyActions extends StatelessWidget {
  const _LocalOnlyActions({required this.sync});

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enable private sync',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
        const SizedBox(height: 7),
        Text(
          'Focused will generate a random 256-bit private key locally. '
          'The raw key is never uploaded to Firebase.',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: sync.isBusy
              ? null
              : () => _generate(context),
          icon: const Icon(
            Icons.key_rounded,
          ),
          label: const Text(
            'Generate Private Key & Enable Sync',
          ),
        ),
      ],
    );
  }

  Future<void> _generate(
    BuildContext context,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Enable private sync?'),
          content: const Text(
            'Focused will create an encrypted cloud copy of your '
            'Focused-owned data. Raw Android app-usage history will stay '
            'on this device.\n\nYou must save the generated private key. '
            'Focused does not upload the raw key and cannot recover it for you.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child:
                  const Text('Generate key'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      final key = await context
          .read<PrivateSyncProvider>()
          .enablePrivateSync();

      if (!context.mounted) return;

      await _showPrivateKeyDialog(
        context,
        key: key,
        title: 'Your Focused Private Key',
        message:
            'Save this somewhere secure. You will need it to authorize '
            'Windows or another device.',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }
}

class _KeyRequiredActions extends StatelessWidget {
  const _KeyRequiredActions({required this.sync});

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: sync.isBusy
              ? null
              : () =>
                  _enterKey(context),
          icon:
              const Icon(Icons.key_rounded),
          label: Text(
            sync.state ==
                    PrivateSyncState.keyChanged
                ? 'Enter New Private Key'
                : 'Enter Existing Private Key',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: sync.isBusy
              ? null
              : sync.refresh,
          child: const Text('Check again'),
        ),
      ],
    );
  }

  Future<void> _enterKey(
    BuildContext context,
  ) async {
    final controller =
        TextEditingController();

    final submitted =
        await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            20 +
                MediaQuery.viewInsetsOf(
                  sheetContext,
                ).bottom,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Focused private key',
                style: Theme.of(sheetContext)
                    .textTheme
                    .headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'The key is checked locally against encrypted account metadata.',
                style: TextStyle(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization:
                    TextCapitalization.characters,
                minLines: 2,
                maxLines: 4,
                decoration:
                    const InputDecoration(
                  labelText:
                      'FCS1 private key',
                  hintText:
                      'FCS1-XXXX-XXXX-...',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(
                        sheetContext,
                        controller.text.trim(),
                      ),
                  child:
                      const Text('Authorize device'),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (submitted == null ||
        submitted.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    try {
      await context
          .read<PrivateSyncProvider>()
          .unlockWithKey(submitted);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Private key accepted on this device.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }
}

class _ReadyActions extends StatelessWidget {
  const _ReadyActions({required this.sync});

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    final lastSync = sync.lastSyncedAt;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (lastSync != null)
          Padding(
            padding:
                const EdgeInsets.only(
              bottom: 14,
            ),
            child: Text(
              'Last encrypted upload: ${_formatTime(lastSync)}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: sync.isBusy
              ? null
              : () =>
                  _reveal(context),
          icon: const Icon(
            Icons.visibility_outlined,
          ),
          label:
              const Text('Show & copy my private key'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: sync.isBusy
              ? null
              : () async {
                  await context
                      .read<PrivateSyncProvider>()
                      .syncNow();

                  if (!context.mounted) {
                    return;
                  }

                  final current = context
                      .read<PrivateSyncProvider>();

                  if (current.errorMessage !=
                      null) {
                    _showError(context);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Encrypted cloud copy is up to date.',
                        ),
                      ),
                    );
                  }
                },
          icon: const Icon(
            Icons.sync_rounded,
          ),
          label: const Text('Sync now'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: sync.isBusy
              ? null
              : () => _rotate(context),
          icon: const Icon(
            Icons.autorenew_rounded,
          ),
          label:
              const Text('Change Private Key'),
        ),
        const SizedBox(height: 24),
        Text(
          'Advanced',
          style: Theme.of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: sync.isBusy ? null : () => _disable(context),
          icon: const FaIcon(FontAwesomeIcons.cloudArrowDown, size: 15),
          label: const Text(
            'Disable Cloud Sync',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _reveal(
    BuildContext context,
  ) async {
    try {
      final key = await context
          .read<PrivateSyncProvider>()
          .revealPrivateKey();

      if (!context.mounted) return;

      await _showPrivateKeyDialog(
        context,
        key: key,
        title: 'Focused Private Key',
        message:
            'This is the secret that authorizes another device to decrypt '
            'your Focused cloud data. Keep it private and save a copy somewhere secure.',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _rotate(
    BuildContext context,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Change private key?'),
          content: const Text(
            '• Focused creates a brand-new private key.\n'
            '• Your current encrypted data remains protected during the change.\n'
            '• The old private key stops working after the change succeeds.\n'
            '• Windows and other devices will ask for the new key before syncing again.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child:
                  const Text('Create new key'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      final key = await context
          .read<PrivateSyncProvider>()
          .rotatePrivateKey();

      if (!context.mounted) return;

      await _showPrivateKeyDialog(
        context,
        key: key,
        title: 'New Focused Private Key',
        message:
            'The old key is no longer valid. Save this new key and enter '
            'it again on Windows or any other connected device.',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _disable(
    BuildContext context,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Disable cloud sync?'),
          content: const Text(
            'The encrypted Focused cloud copy and private-sync metadata '
            'will be deleted. Your local tasks, habits and focus history '
            'will remain on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child:
                  const Text('Disable sync'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      await context
          .read<PrivateSyncProvider>()
          .disablePrivateSync();
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour =
        local.hour.toString().padLeft(2, '0');
    final minute =
        local.minute.toString().padLeft(2, '0');

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}

class _RemoteChangedActions
    extends StatelessWidget {
  const _RemoteChangedActions({
    required this.sync,
  });

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        Text(
          'Focused blocked an overwrite because another device changed '
          'the cloud revision.',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: sync.refresh,
          child:
              const Text('Refresh cloud state'),
        ),
        const SizedBox(height: 8),
        Text(
          'Automatic conflict merging will be added with the Windows '
          'cross-device sync phase.',
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

class _ErrorActions extends StatelessWidget {
  const _ErrorActions({required this.sync});

  final PrivateSyncProvider sync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        if (sync.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer,
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Text(
              sync.errorMessage!,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onErrorContainer,
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: sync.refresh,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}


class _PrivacyExplanation extends StatelessWidget {
  const _PrivacyExplanation();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.58,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.shieldHalved,
                size: 17,
                color: scheme.primary,
              ),
              const SizedBox(width: 9),
              Text(
                'What gets uploaded?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _PrivacyBullet(
            title: 'Encrypted before upload',
            body:
                'Tasks, recurring-task completions, habits, habit progress, focus-session history, focus analyses, app classifications, streak goal and profile state.',
          ),
          const SizedBox(height: 10),
          const _PrivacyBullet(
            title: 'Stays on this device',
            body: 'Raw Android UsageStats and raw app-usage event history.',
          ),
          const SizedBox(height: 10),
          const _PrivacyBullet(
            title: 'Firebase cannot read the FCS1 key',
            body:
                'Firebase stores ciphertext, encrypted key metadata and the current key version — never your raw private key.',
          ),
        ],
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title — ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: body),
              ],
            ),
            style: TextStyle(color: scheme.onSurface, height: 1.4),
          ),
        ),
      ],
    );
  }
}

Future<void> _showPrivateKeyDialog(
  BuildContext context, {
  required String key,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var copied = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: SelectableText(
                      key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight:
                            FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: key,
                        ),
                      );

                      setState(() {
                        copied = true;
                      });
                    },
                    icon: Icon(
                      copied
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                    ),
                    label: Text(
                      copied
                          ? 'Copied'
                          : 'Copy key',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                      dialogContext,
                    ),
                child: const Text(
                  'I saved my key',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showError(BuildContext context) {
  final sync =
      context.read<PrivateSyncProvider>();

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      content: Text(
        sync.errorMessage ??
            'Private sync failed. Please try again.',
      ),
    ),
  );
}

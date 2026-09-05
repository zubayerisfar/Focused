import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_limit.dart';
import '../providers/app_limit_provider.dart';
import '../providers/usage_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';

class AppLimitsScreen extends StatelessWidget {
  const AppLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usageProvider = context.watch<UsageProvider>();
    final limitProvider = context.watch<AppLimitProvider>();

    final apps = usageProvider.topAppEntriesToday(limit: 500);
    final limits = limitProvider.limits;

    // Collect all apps that either have usage today OR have a configured limit
    final appMap = <String, _AppLimitViewItem>{};

    for (final app in apps) {
      final limit = limitProvider.getLimit(app.appId);
      appMap[app.appId] = _AppLimitViewItem(
        packageId: app.appId,
        appName: app.appName,
        todayUsage: app.duration,
        iconBytes: app.iconBytes,
        limit: limit,
      );
    }

    for (final limit in limits) {
      if (!appMap.containsKey(limit.packageId)) {
        final metadata = usageProvider.getAppMetadata(limit.packageId);
        appMap[limit.packageId] = _AppLimitViewItem(
          packageId: limit.packageId,
          appName: limit.appName,
          todayUsage: Duration.zero,
          iconBytes: metadata?.iconBytes,
          limit: limit,
        );
      }
    }

    final items = appMap.values.toList()
      ..sort((a, b) {
        // Apps with limits first, then by usage duration descending
        final aHasLimit = a.limit != null && a.limit!.isEnabled ? 1 : 0;
        final bHasLimit = b.limit != null && b.limit!.isEnabled ? 1 : 0;
        if (aHasLimit != bHasLimit) return bHasLimit.compareTo(aHasLimit);
        return b.todayUsage.compareTo(a.todayUsage);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Limits & Timers',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stay Mindful of Screen Time',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set daily time limits for apps. Focused will alert you with a high-priority notification as soon as you reach your limit.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Applications',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Text(
                'No app usage recorded yet for today.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ] else ...[
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AppLimitTile(
                  item: item,
                  onTap: () => _showLimitBottomSheet(context, item),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLimitBottomSheet(BuildContext context, _AppLimitViewItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SetAppLimitSheet(item: item),
    );
  }
}

class _AppLimitViewItem {
  final String packageId;
  final String appName;
  final Duration todayUsage;
  final Uint8List? iconBytes;
  final AppLimit? limit;

  const _AppLimitViewItem({
    required this.packageId,
    required this.appName,
    required this.todayUsage,
    this.iconBytes,
    this.limit,
  });
}

class _AppLimitTile extends StatelessWidget {
  const _AppLimitTile({required this.item, required this.onTap});

  final _AppLimitViewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final limit = item.limit;
    final hasActiveLimit = limit != null && limit.isEnabled;

    final usedMinutes = item.todayUsage.inMinutes;
    final limitMinutes = limit?.dailyLimitMinutes ?? 0;

    double progress = 0.0;
    if (hasActiveLimit && limitMinutes > 0) {
      progress = (usedMinutes / limitMinutes).clamp(0.0, 1.0);
    }

    final isOverLimit = hasActiveLimit && usedMinutes >= limitMinutes;

    Color progressColor;
    if (isOverLimit) {
      progressColor = const Color(0xFFEF4444);
    } else if (progress >= 0.75) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = const Color(0xFF10B981);
    }

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOverLimit
                  ? const Color(0xFFEF4444).withOpacity(0.5)
                  : theme.dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(
                    iconBytes: item.iconBytes,
                    appName: item.appName,
                    size: 42,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.appName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasActiveLimit
                              ? (isOverLimit
                                    ? '⚠️ ${usedMinutes - limitMinutes}m over daily limit'
                                    : '${limitMinutes - usedMinutes}m remaining of ${_formatMinutes(limitMinutes)}')
                              : 'Used ${_formatMinutes(usedMinutes)} today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOverLimit
                                ? const Color(0xFFEF4444)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (limit != null)
                    Switch.adaptive(
                      value: limit.isEnabled,
                      onChanged: (val) {
                        context.read<AppLimitProvider>().toggleLimit(
                          item.packageId,
                        );
                      },
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (hasActiveLimit) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _SetAppLimitSheet extends StatefulWidget {
  const _SetAppLimitSheet({required this.item});

  final _AppLimitViewItem item;

  @override
  State<_SetAppLimitSheet> createState() => _SetAppLimitSheetState();
}

class _SetAppLimitSheetState extends State<_SetAppLimitSheet> {
  late int _selectedMinutes;
  bool _isCustom = false;
  late final TextEditingController _customHoursController;
  late final TextEditingController _customMinsController;

  static const List<int> _presets = [15, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    final existingLimit = widget.item.limit?.dailyLimitMinutes;
    _selectedMinutes = existingLimit ?? 60;
    _isCustom = !_presets.contains(_selectedMinutes);

    _customHoursController = TextEditingController(
      text: (_selectedMinutes ~/ 60).toString(),
    );
    _customMinsController = TextEditingController(
      text: (_selectedMinutes % 60).toString(),
    );
  }

  @override
  void dispose() {
    _customHoursController.dispose();
    _customMinsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasExisting = widget.item.limit != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                iconBytes: widget.item.iconBytes,
                appName: widget.item.appName,
                size: 40,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.appName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Daily Usage Limit',
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
          const SizedBox(height: 20),
          const Text(
            'Select daily time limit:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._presets.map(
                (minutes) => ChoiceChip(
                  label: Text(_formatPreset(minutes)),
                  selected: !_isCustom && _selectedMinutes == minutes,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMinutes = minutes;
                        _isCustom = false;
                      });
                    }
                  },
                ),
              ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _isCustom,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _isCustom = true);
                  }
                },
              ),
            ],
          ),
          if (_isCustom) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _updateCustomMinutes(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _customMinsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _updateCustomMinutes(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () async {
                if (_selectedMinutes <= 0) return;
                await context.read<AppLimitProvider>().setLimit(
                  packageId: widget.item.packageId,
                  appName: widget.item.appName,
                  dailyLimitMinutes: _selectedMinutes,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                'Save Limit',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () async {
                  await context.read<AppLimitProvider>().removeLimit(
                    widget.item.packageId,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove Limit'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateCustomMinutes() {
    final h = int.tryParse(_customHoursController.text) ?? 0;
    final m = int.tryParse(_customMinsController.text) ?? 0;
    setState(() {
      _selectedMinutes = (h * 60) + m;
    });
  }

  String _formatPreset(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hour${hours > 1 ? 's' : ''}';
    return '${hours}h ${mins}m';
  }
}

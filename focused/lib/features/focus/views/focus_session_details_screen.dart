import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/focus_analysis_result.dart';
import '../../../models/focus_session.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/usage_provider.dart';

class FocusSessionDetailsScreen extends StatelessWidget {
  final String sessionId;

  const FocusSessionDetailsScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final usage = context.watch<UsageProvider>();

    FocusSession? session;
    for (final item in focus.sessionHistory) {
      if (item.id == sessionId) {
        session = item;
        break;
      }
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Focus session not found.')),
      );
    }

    final analysis = usage.storedFocusAnalyses[session.id];

    return Scaffold(
      appBar: AppBar(title: const Text('Focus session')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          Text(
            session.taskName.trim().isEmpty
                ? 'Open focus session'
                : session.taskName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMM d • h:mm a').format(session.startedAt),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          _MetricGrid(session: session, analysis: analysis),
          if (analysis != null) ...[
            const SizedBox(height: 24),
            _InterruptionSummary(analysis: analysis),
          ],
          if (session.taskId != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                final day = session!.linkedOccurrenceDate ?? session.startedAt;
                context.push(
                  '/task/${Uri.encodeComponent(session.taskId!)}?date=${_dateQuery(day)}',
                );
              },
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('View task'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final FocusSession session;
  final FocusAnalysisResult? analysis;

  const _MetricGrid({
    required this.session,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData)>[
      (
        _formatDuration(session.actualFocusDuration),
        'Focused',
        Icons.center_focus_strong_rounded,
      ),
      (
        _formatDuration(session.plannedFocusDuration),
        'Planned',
        Icons.schedule_rounded,
      ),
      (
        _formatDuration(session.breakDuration),
        'Breaks',
        Icons.free_breakfast_outlined,
      ),
      (
        analysis == null ? '—' : _formatDuration(analysis!.effectiveFocusDuration),
        'Effective focus',
        Icons.bolt_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricCard(
                    value: item.$1,
                    label: item.$2,
                    icon: item.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _InterruptionSummary extends StatelessWidget {
  final FocusAnalysisResult analysis;

  const _InterruptionSummary({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus interruptions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _RowValue(
            label: 'Interruptions',
            value: '${analysis.interruptionCount}',
          ),
          _RowValue(
            label: 'Distracted time',
            value: _formatDuration(analysis.distractedDuration),
          ),
          _RowValue(
            label: 'Focus quality',
            value: '${analysis.focusQuality.round()}%',
          ),
          if (analysis.topInterrupterApp != null)
            _RowValue(
              label: 'Top interrupter',
              value: _cleanAppName(analysis.topInterrupterApp!),
            ),
        ],
      ),
    );
  }
}

class _RowValue extends StatelessWidget {
  final String label;
  final String value;

  const _RowValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

String _cleanAppName(String value) {
  if (!value.contains('.')) return value;
  final parts = value.split('.').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return value;
  final last = parts.last;
  return '${last[0].toUpperCase()}${last.substring(1)}';
}

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

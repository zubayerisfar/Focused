import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../providers/focus_provider.dart';

class FocusSessionDetailsScreen extends StatelessWidget {
  final String sessionId;

  const FocusSessionDetailsScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();

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
          _MetricGrid(session: session),
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

  const _MetricGrid({required this.session});

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
        session.completedNaturally ? 'Completed' : 'Ended early',
        'Status',
        session.completedNaturally
            ? Icons.check_circle_rounded
            : Icons.flag_rounded,
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

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}

String _dateQuery(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

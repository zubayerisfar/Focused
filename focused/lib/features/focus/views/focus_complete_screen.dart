import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../providers/focus_provider.dart';
import '../../../core/services/ad_service.dart';

class FocusCompleteScreen extends StatelessWidget {
  const FocusCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusProvider = context.watch<FocusProvider>();
    final session = focusProvider.lastSession;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No completed session found.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  context.go('/');
                },
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
          children: [
            Text(
              session.completedNaturally ? 'Nice work! 🎉' : 'Session ended',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              session.taskName.trim().isEmpty
                  ? 'Open focus session'
                  : session.taskName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 28),
            _SessionResultsCard(session: session),
            if (session.taskScheduledStart != null &&
                session.taskScheduledEnd != null) ...[
              const SizedBox(height: 24),
              _ScheduleExecutionCard(session: session),
            ],
            if (focusProvider.lastPersistenceError != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This session is visible now, but Focused could not save it to local history. '
                        'Do not clear the app until the storage issue is fixed.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 34),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: () async {
                  await focusProvider.flushPendingPersistence();

                  if (!context.mounted) {
                    return;
                  }

                  AdService.instance.showInterstitialAd(
                    onAdClosed: () {
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                  );
                },
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleExecutionCard extends StatelessWidget {
  final FocusSession session;

  const _ScheduleExecutionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final start = session.taskScheduledStart!;
    final end = session.taskScheduledEnd!;
    final planned = end.difference(start);
    final actualStart = session.focusIntervals.isEmpty
        ? session.startedAt
        : session.focusIntervals.first.startTime;
    final offset = actualStart.difference(start);
    final active = session.actualFocusDuration;
    final scheme = Theme.of(context).colorScheme;

    double coverage(Duration duration) {
      if (planned.inSeconds <= 0) return 0;
      return duration.inSeconds / planned.inSeconds * 100;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Schedule execution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ExecutionLine(
            label: 'Planned',
            value: '${_clock(start)} – ${_clock(end)}',
          ),
          const SizedBox(height: 9),
          _ExecutionLine(
            label: 'Started',
            value: '${_clock(actualStart)} • ${_timingLabel(offset)}',
          ),
          const SizedBox(height: 9),
          _ExecutionLine(
            label: 'Calendar duration',
            value: _durationShort(planned),
          ),
          const SizedBox(height: 9),
          _ExecutionLine(
            label: 'Active focus',
            value:
                '${_durationShort(active)} • ${coverage(active).round()}% of plan',
          ),
        ],
      ),
    );
  }
}

class _ExecutionLine extends StatelessWidget {
  final String label;
  final String value;

  const _ExecutionLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _timingLabel(Duration offset) {
  if (offset.isNegative) {
    return '${_durationShort(Duration(microseconds: -offset.inMicroseconds))} early';
  }
  if (offset.compareTo(const Duration(minutes: 5)) <= 0) return 'On time';
  return '${_durationShort(offset)} late';
}

String _durationShort(Duration value) {
  final minutes = value.inMinutes.abs();
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _SessionResultsCard extends StatelessWidget {
  final FocusSession session;

  const _SessionResultsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResultMetric(
                label: 'Focused',
                value: _durationShort(session.actualFocusDuration),
                icon: Icons.timer_rounded,
                color: scheme.primary,
              ),
              Container(
                width: 1,
                height: 40,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              _ResultMetric(
                label: 'Planned',
                value: _durationShort(session.plannedFocusDuration),
                icon: Icons.flag_rounded,
                color: scheme.secondary,
              ),
              Container(
                width: 1,
                height: 40,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              _ResultMetric(
                label: 'Breaks',
                value: _durationShort(session.breakDuration),
                icon: Icons.coffee_rounded,
                color: Colors.amber.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

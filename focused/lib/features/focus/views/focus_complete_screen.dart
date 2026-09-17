import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../providers/focus_provider.dart';
import '../../../core/theme/app_theme.dart';

import '../models/focus_analysis_result.dart';
import '../../wellbeing/providers/usage_provider.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/widgets/app_icon.dart';

class FocusCompleteScreen extends StatefulWidget {
  const FocusCompleteScreen({super.key});

  @override
  State<FocusCompleteScreen> createState() {
    return _FocusCompleteScreenState();
  }
}

class _FocusCompleteScreenState extends State<FocusCompleteScreen> {
  bool _analysisRequested = false;

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
    if (!_analysisRequested) {
      _analysisRequested = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        context.read<UsageProvider>().analyzeCompletedFocusSession(session);
      });
    }
    final usageProvider = context.watch<UsageProvider>();
    final analysis = usageProvider.focusAnalysisResult;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
          children: [
            Text(
              session.completedNaturally ? 'Nice work!' : 'Session ended',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              session.taskName,
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
              _ScheduleExecutionCard(
                session: session,
                analysis: analysis,
                analysisPending: usageProvider.isAnalyzingFocus,
              ),
            ],

            const SizedBox(height: 24),

            if (usageProvider.isAnalyzingFocus) ...[
              const _UsageAnalysisLoadingCard(),
              const SizedBox(height: 24),
            ] else if (analysis != null) ...[
              _FocusQualityCard(session: session, analysis: analysis),
              const SizedBox(height: 24),
            ] else if (usageProvider.analysisUnavailableReason != null) ...[
              _UsageAnalysisUnavailableCard(
                message: usageProvider.analysisUnavailableReason!,
              ),
              const SizedBox(height: 24),
            ],
            if (focusProvider.lastPersistenceError != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This session is visible now, but Focused could not save it to local history. '
                        'Do not clear the app until the storage issue is fixed.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
  final FocusAnalysisResult? analysis;
  final bool analysisPending;

  const _ScheduleExecutionCard({
    required this.session,
    required this.analysis,
    required this.analysisPending,
  });

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
    final effective = analysis?.effectiveFocusDuration;
    final scheme = Theme.of(context).colorScheme;

    double coverage(Duration duration) {
      if (planned.inSeconds <= 0) return 0;
      return duration.inSeconds / planned.inSeconds * 100;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.34),
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
            label: 'Last active focus',
            value: session.focusIntervals.isEmpty
                ? 'No active focus recorded'
                : _clock(session.focusIntervals.last.endTime),
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
          const SizedBox(height: 9),
          _ExecutionLine(
            label: 'Effective focus',
            value: effective == null
                ? (analysisPending ? 'Analyzing app usage…' : 'Unavailable')
                : '${_durationShort(effective)} • ${coverage(effective).round()}% of plan',
          ),
          const SizedBox(height: 12),
          Text(
            'The original calendar window is stored with this focus session, so later task edits do not rewrite this execution history.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
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
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(session.actualFocusDuration),
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Total focused time',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 28),
          _CleanStatRow(
            label: 'Planned focus',
            value: _formatDuration(session.plannedFocusDuration),
          ),
          const SizedBox(height: 12),
          _CleanStatRow(
            label: 'Focus blocks',
            value:
                '${session.completedFocusBlocks}/${session.totalFocusBlocks}',
          ),
          if (session.breakDuration.inMicroseconds > 0) ...[
            const SizedBox(height: 12),
            _CleanStatRow(
              label: 'Break time',
              value: _formatDuration(session.breakDuration),
            ),
          ],
          if (session.pausedDuration.inMicroseconds > 0) ...[
            const SizedBox(height: 12),
            _CleanStatRow(
              label: 'Paused time',
              value: _formatDuration(session.pausedDuration),
            ),
          ],
        ],
      ),
    );
  }
}

class _CleanStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _CleanStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _UsageAnalysisLoadingCard extends StatelessWidget {
  const _UsageAnalysisLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reading real Android app activity for this focus session…',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageAnalysisUnavailableCard extends StatelessWidget {
  final String message;

  const _UsageAnalysisUnavailableCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusQualityCard extends StatelessWidget {
  final FocusSession session;
  final FocusAnalysisResult analysis;

  const _FocusQualityCard({required this.session, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final usageProvider = context.watch<UsageProvider>();
    final quality = analysis.focusQuality.round();
    final hasDistraction = analysis.interruptionCount > 0;
    final distractionEntries = analysis.distractionByApp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String appIdForName(String appName) {
      for (final interruption in analysis.interruptions) {
        if (interruption.appName == appName) {
          return interruption.appId;
        }
      }
      return usageProvider.resolveAppIdForName(appName) ?? appName;
    }

    final topInterrupterId = analysis.topInterrupterApp == null
        ? null
        : appIdForName(analysis.topInterrupterApp!);
    final topInterrupterName = analysis.topInterrupterApp == null
        ? null
        : usageProvider.resolveDisplayName(
            topInterrupterId!,
            fallback: analysis.topInterrupterApp,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: analysis.focusQuality / 100,
                        strokeWidth: 6,
                        backgroundColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                        color: quality >= 80
                            ? const Color(0xFF34B27B)
                            : quality >= 50
                            ? Colors.orange
                            : Colors.redAccent,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '$quality%',
                          style: const TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Focus quality',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !hasDistraction
                          ? 'Zero distracting apps opened during focus.'
                          : '${analysis.interruptionCount} distraction${analysis.interruptionCount == 1 ? '' : 's'} detected (${_formatDuration(analysis.distractedDuration)})',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDistraction) ...[
            const Divider(height: 28),
            _CleanStatRow(
              label: 'Effective focus',
              value: _formatDuration(analysis.effectiveFocusDuration),
            ),
            const SizedBox(height: 12),
            _CleanStatRow(
              label: 'Distracted time',
              value: _formatDuration(analysis.distractedDuration),
            ),
            if (topInterrupterName != null) ...[
              const SizedBox(height: 12),
              _CleanStatRow(
                label: 'Main interrupter',
                value: topInterrupterName,
              ),
            ],
          ],
          if (analysis.distractionByApp.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              'Distracting apps',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...distractionEntries.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DistractionAppRow(
                  appName: usageProvider.resolveDisplayName(
                    appIdForName(entry.key),
                    fallback: entry.key,
                  ),
                  iconBytes: usageProvider
                      .getAppMetadata(appIdForName(entry.key))
                      ?.iconBytes,
                  duration: entry.value,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DistractionAppRow extends StatelessWidget {
  final String appName;
  final Uint8List? iconBytes;
  final Duration duration;

  const _DistractionAppRow({
    required this.appName,
    required this.iconBytes,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        AppIcon(
          iconBytes: iconBytes,
          appName: appName,
          size: 36,
          borderRadius: 11,
          fallbackBackground: scheme.errorContainer.withOpacity(0.65),
          fallbackForeground: scheme.onErrorContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          _formatDuration(duration),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds < 60) {
    return '${duration.inSeconds}s';
  }

  final totalMinutes = duration.inMinutes;

  final hours = totalMinutes ~/ 60;

  final minutes = totalMinutes % 60;

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

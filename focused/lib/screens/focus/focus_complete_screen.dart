import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';

import '../../models/focus_analysis_result.dart';
import '../../providers/usage_provider.dart';
import '../../services/ad_service.dart';
import '../../widgets/app_icon.dart';

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

    final taskProvider = context.watch<TaskProvider>();
    final linkedTask = session.taskId == null
        ? null
        : taskProvider.getTaskById(session.taskId!);

    final linkedDay = session.linkedOccurrenceDate ?? session.startedAt;
    final sessionDate = DateTime(
      linkedDay.year,
      linkedDay.month,
      linkedDay.day,
    );

    final linkedTaskCompleted =
        linkedTask != null &&
        taskProvider.isTaskCompletedForDate(linkedTask, sessionDate);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          children: [
            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF34B27B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  session.completedNaturally
                      ? Icons.check_rounded
                      : Icons.stop_rounded,
                  size: 52,
                  color: const Color(0xFF34B27B),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              session.completedNaturally ? 'Nice work!' : 'Session ended',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            Text(
              session.taskName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),

            const SizedBox(height: 38),

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

            if (linkedTask != null) ...[
              _LinkedTaskCompletionCard(
                taskName: linkedTask.title,
                isCompleted: linkedTaskCompleted,
              ),
              const SizedBox(height: 24),
            ],

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primaryBlue,
                    size: 32,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      session.completedNaturally
                          ? 'Your focus session was completed successfully.'
                          : 'Your completed focus time was still recorded.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

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

class _LinkedTaskCompletionCard extends StatelessWidget {
  final String taskName;
  final bool isCompleted;

  const _LinkedTaskCompletionCard({
    required this.taskName,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? AppTheme.success
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.task_alt_rounded : Icons.sync_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? 'Task completed' : 'Finishing task…',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isCompleted
                      ? '“$taskName” was completed when this focus session ended.'
                      : 'Focused is updating “$taskName” as completed.',
                  style: TextStyle(
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionResultsCard extends StatelessWidget {
  final FocusSession session;

  const _SessionResultsCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _ResultRow(
            icon: Icons.timer_rounded,
            title: 'Actual focused time',
            value: _formatDuration(session.actualFocusDuration),
            color: AppTheme.primaryBlue,
          ),

          const Divider(height: 30),

          _ResultRow(
            icon: Icons.flag_outlined,
            title: 'Planned focus',
            value: _formatDuration(session.plannedFocusDuration),
            color: const Color(0xFF8E67D4),
          ),

          const Divider(height: 30),

          _ResultRow(
            icon: Icons.check_circle_rounded,
            title: 'Focus blocks',
            value:
                '${session.completedFocusBlocks}'
                '/${session.totalFocusBlocks}',
            color: const Color(0xFF34B27B),
          ),

          if (session.breakDuration.inMicroseconds > 0) ...[
            const Divider(height: 30),

            _ResultRow(
              icon: Icons.free_breakfast_rounded,
              title: 'Break time',
              value: _formatDuration(session.breakDuration),
              color: const Color(0xFF34B27B),
            ),
          ],

          if (session.pausedDuration.inMicroseconds > 0) ...[
            const Divider(height: 30),

            _ResultRow(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Paused time',
              value: _formatDuration(session.pausedDuration),
              color: Colors.blueGrey,
            ),
          ],

          const Divider(height: 30),

          _ResultRow(
            icon: Icons.schedule_rounded,
            title: 'Session elapsed',
            value: _formatDuration(session.totalElapsedDuration),
            color: Colors.orange,
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(20),
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
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: analysis.focusQuality / 100,
                      strokeWidth: 7,
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.10),
                    ),

                    Text(
                      '$quality%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      analysis.interruptionCount == 0
                          ? 'No distracting app usage was detected during active focus time.'
                          : '${analysis.interruptionCount} distracting app interruption${analysis.interruptionCount == 1 ? '' : 's'} detected.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          _AnalysisRow(
            label: 'Timer focus',
            value: _formatDuration(session.actualFocusDuration),
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Effective focus',
            value: _formatDuration(analysis.effectiveFocusDuration),
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Distracted',
            value: _formatDuration(analysis.distractedDuration),
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Interruptions',
            value: '${analysis.interruptionCount}',
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Top interrupter',
            value: topInterrupterName ?? 'None',
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Attention retained',
            value: '${analysis.attentionRetention.round()}%',
          ),

          const SizedBox(height: 14),

          _AnalysisRow(
            label: 'Plan completion',
            value: '${analysis.completionRate.round()}%',
          ),

          if (analysis.distractionByApp.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Distracting apps',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
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

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;

  const _AnalysisRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ),

        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ResultRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

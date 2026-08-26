import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_provider.dart';
import '../../theme/app_theme.dart';

import '../../models/focus_analysis_result.dart';
import '../../providers/usage_provider.dart';

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
    final session = context.watch<FocusProvider>().lastSession;

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
    final analysis = context.watch<UsageProvider>().focusAnalysisResult;

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
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
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

            const SizedBox(height: 24),

            if (analysis != null) ...[
              _FocusQualityCard(session: session, analysis: analysis),

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
                onPressed: () {
                  context.go('/');
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

class _FocusQualityCard extends StatelessWidget {
  final FocusSession session;
  final FocusAnalysisResult analysis;

  const _FocusQualityCard({required this.session, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final quality = analysis.focusQuality.round();

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
                        fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w800,
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
            value: analysis.topInterrupterApp ?? 'None',
          ),
        ],
      ),
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

        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

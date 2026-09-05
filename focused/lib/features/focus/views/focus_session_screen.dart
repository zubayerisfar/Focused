import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/focus_provider.dart';
import '../../../theme/app_theme.dart';

class FocusSessionScreen extends StatelessWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();

    if (focus.sessionFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/focus/complete');
        }
      });

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!focus.isRunning) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_off_outlined, size: 52),

                const SizedBox(height: 16),

                const Text(
                  'No active focus session',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: () {
                    context.go('/focus/setup');
                  },
                  child: const Text('Set Up Focus'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isBreak = focus.isBreak;

    final activeColor = isBreak
        ? const Color(0xFF34B27B)
        : AppTheme.primaryBlue;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _showExitConfirmation(context);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),

                  const Spacer(),

                  Text(
                    isBreak ? 'Break' : 'Focus',
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const Spacer(),

                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              Icon(
                isBreak ? Icons.free_breakfast_rounded : Icons.timer_rounded,
                size: 44,
                color: activeColor,
              ),

              const SizedBox(height: 18),

              Text(
                isBreak ? 'Take a break' : focus.taskName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isBreak
                    ? 'Break after focus block '
                          '${focus.completedFocusBlocks} '
                          'of ${focus.totalFocusBlocks}'
                    : 'Focus block '
                          '${focus.currentFocusBlockNumber} '
                          'of ${focus.totalFocusBlocks}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.50),
                ),
              ),

              const SizedBox(height: 14),

              _FocusGuardStatusCard(focus: focus),

              const SizedBox(height: 28),

              SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: focus.currentBlockProgress,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        backgroundColor: activeColor.withOpacity(0.12),
                        color: activeColor,
                      ),
                    ),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatClock(focus.remainingSeconds),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          focus.isPaused ? 'Paused' : 'Remaining',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (!isBreak)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showExitConfirmation(context);
                        },
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (focus.isPaused) {
                            context.read<FocusProvider>().resumeSession();
                          } else {
                            context.read<FocusProvider>().pauseSession();
                          }
                        },
                        icon: Icon(
                          focus.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(focus.isPaused ? 'Resume' : 'Pause'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                  ],
                ),

              if (isBreak)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showExitConfirmation(context);
                        },
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('End'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.read<FocusProvider>().skipBreak();
                        },
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Skip Break'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              if (isBreak)
                Text(
                  'The next focus block starts automatically when the break ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_off_outlined, size: 42),

                const SizedBox(height: 12),

                Text(
                  'End focus session?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 8),

                Text(
                  'The focus time you completed will still be included in this session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      context.read<FocusProvider>().endSession();

                      context.go('/focus/complete');
                    },
                    child: const Text('End Session'),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Keep Focusing'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _FocusGuardStatusCard extends StatelessWidget {
  final FocusProvider focus;

  const _FocusGuardStatusCard({required this.focus});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = focus.focusGuardStatus;

    IconData icon = Icons.shield_outlined;
    String text;
    Color foreground = scheme.primary;

    if (focus.focusGuardError != null) {
      icon = Icons.warning_amber_rounded;
      foreground = scheme.error;
      text = 'Focus Guard could not start. Focus timing still continues.';
    } else if (focus.isPaused) {
      icon = Icons.pause_circle_outline_rounded;
      text = 'Focus Guard paused';
    } else if (focus.isBreak) {
      icon = Icons.free_breakfast_outlined;
      text = 'Focus Guard rests during breaks • timer stays active';
    } else if (status.serviceRunning && !status.usageAccessGranted) {
      icon = Icons.warning_amber_rounded;
      foreground = const Color(0xFFB26A00);
      text = 'Usage Access is off • live app warnings are unavailable';
    } else if (status.serviceRunning && !status.notificationsEnabled) {
      icon = Icons.notifications_off_outlined;
      foreground = const Color(0xFFB26A00);
      text = 'Notifications are off • background warnings may be hidden';
    } else if (status.serviceRunning) {
      icon = Icons.shield_rounded;
      text = 'Focus Guard active • ${status.warningThresholdSeconds}s outside-workspace warning';
    } else {
      text = 'Starting Focus Guard…';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: foreground.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;

  final seconds = totalSeconds % 60;

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

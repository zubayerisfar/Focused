import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_provider.dart';
import '../../theme/app_theme.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusProvider =
        context.watch<FocusProvider>();
    final now = DateTime.now();

    final focusedToday =
        focusProvider.focusedDurationForDate(now);
    final sessionsToday =
        focusProvider.sessionCountForDate(now);
    final latestSession =
        focusProvider.latestSession;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        120,
      ),
      children: [
        Text(
          'Ready to focus?',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a task, remove distractions, and make progress.',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.55),
          ),
        ),

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.timer_rounded,
                value: _formatDuration(
                  focusedToday,
                ),
                label: 'Focused today',
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon:
                    Icons.history_rounded,
                value: '$sessionsToday',
                label: sessionsToday == 1
                    ? 'Session today'
                    : 'Sessions today',
                color:
                    const Color(0xFF8E67D4),
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),

        Text(
          'Focus history',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surface,
            borderRadius:
                BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.save_rounded,
                size: 38,
                color:
                    Color(0xFF34B27B),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      '${focusProvider.sessionHistory.length} '
                      '${focusProvider.sessionHistory.length == 1 ? 'session' : 'sessions'} saved',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Focus history is stored locally and survives app restarts.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurface
                            .withOpacity(0.52),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        Text(
          'Last session',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        if (latestSession != null)
          _LastSessionCard(
            session: latestSession,
          )
        else
          const _NoSessionCard(),

        const SizedBox(height: 32),

        SizedBox(
          height: 60,
          child: FilledButton.icon(
            onPressed: () {
              context.push(
                '/focus/setup',
              );
            },
            icon: const Icon(
              Icons.play_arrow_rounded,
            ),
            label: const Text(
              'Start Focus',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.50),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastSessionCard
    extends StatelessWidget {
  final FocusSession session;

  const _LastSessionCard({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final status = session.completedNaturally
        ? 'Completed'
        : 'Ended early';

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor:
                Color(0x184D7CFE),
            child: Icon(
              Icons.task_alt_rounded,
              color:
                  AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  session.taskName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDuration(session.actualFocusDuration)} • '
                  '$status • '
                  '${DateFormat('EEE, h:mm a').format(session.endedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            session.completedNaturally
                ? Icons
                    .check_circle_rounded
                : Icons.stop_circle_rounded,
            color: session
                    .completedNaturally
                ? const Color(
                    0xFF34B27B,
                  )
                : Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _NoSessionCard
    extends StatelessWidget {
  const _NoSessionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.45),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Complete a focus session and it will appear here.',
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds <= 0) {
    return '0 min';
  }

  if (duration.inSeconds < 60) {
    return '<1 min';
  }

  final totalMinutes =
      duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes =
      totalMinutes % 60;

  if (hours == 0) {
    return '$minutes min';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

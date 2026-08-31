import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../theme/app_theme.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusProvider>();
    final account = context.watch<AccountProvider>();
    final now = DateTime.now();
    final focusedToday = provider.focusedDurationForDate(now);
    final sessionsToday = provider.sessionCountForDate(now);
    final longest = provider.longestFocusSessionForDate(now);
    final recent = provider.sessionHistory.take(5).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Row(
            children: [
              Text(
                'Focus',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push('/profile'),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 21,
                    backgroundImage: account.photoUrl == null
                        ? null
                        : NetworkImage(account.photoUrl!),
                    child: account.photoUrl == null
                        ? Text(
                            _initials(account.displayName),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FocusHero(
            running: provider.isRunning,
            paused: provider.isPaused,
            taskName: provider.taskName,
            focusedToday: focusedToday,
            remainingSeconds: provider.remainingSeconds,
            onPressed: () => context.push(
              provider.isRunning ? '/focus/session' : '/focus/setup',
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FocusMetric(
                  icon: Icons.layers_rounded,
                  value: '$sessionsToday',
                  label: 'sessions today',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FocusMetric(
                  icon: Icons.emoji_events_outlined,
                  value: _formatDuration(longest),
                  label: 'longest today',
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Text(
                'Recent sessions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (recent.isNotEmpty)
                Text(
                  '${provider.sessionHistory.length} saved',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const _FocusEmptyHistory()
          else
            ...recent.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionHistoryTile(session: session),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusHero extends StatelessWidget {
  final bool running;
  final bool paused;
  final String taskName;
  final Duration focusedToday;
  final int remainingSeconds;
  final VoidCallback onPressed;

  const _FocusHero({
    required this.running,
    required this.paused,
    required this.taskName,
    required this.focusedToday,
    required this.remainingSeconds,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = Duration(
      seconds: remainingSeconds < 0 ? 0 : remainingSeconds,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withOpacity(0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: scheme.primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      running
                          ? Icons.radio_button_checked_rounded
                          : Icons.center_focus_strong_rounded,
                      size: 17,
                      color: running
                          ? (paused ? AppTheme.warning : AppTheme.success)
                          : scheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      running
                          ? (paused ? 'Paused' : 'In focus')
                          : 'Ready',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                running
                    ? _formatClock(remaining)
                    : '${_formatDuration(focusedToday)} today',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            width: 138,
            height: 138,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface.withOpacity(0.82),
              border: Border.all(
                color: scheme.primary.withOpacity(0.22),
                width: 9,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  running
                      ? Icons.timer_rounded
                      : Icons.psychology_alt_rounded,
                  size: 34,
                  color: scheme.primary,
                ),
                const SizedBox(height: 7),
                Text(
                  running
                      ? _formatClock(remaining)
                      : _formatDuration(focusedToday),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  running ? 'remaining' : 'focused today',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              running
                  ? (taskName.trim().isEmpty
                      ? 'Open focus session'
                      : taskName)
                  : 'Make the next block count.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              running
                  ? 'Stay with the work you chose. Your actual active-focus time is being recorded.'
                  : 'Choose a task or start an open session. Focused will record your real active time and later compare it with app usage.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withOpacity(0.78),
                    height: 1.4,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(
                running
                    ? Icons.open_in_full_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                running ? 'Return to session' : 'Start focus',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _FocusMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
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

class _SessionHistoryTile extends StatelessWidget {
  final FocusSession session;

  const _SessionHistoryTile({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          '/focus/history/${Uri.encodeComponent(session.id)}',
        ),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.check_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskName.trim().isEmpty
                      ? 'Open focus session'
                      : session.taskName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDuration(session.actualFocusDuration)} active • ${DateFormat('MMM d, h:mm a').format(session.endedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
    );
  }
}

class _FocusEmptyHistory extends StatelessWidget {
  const _FocusEmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your focus history starts here',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Finish a session and its real active-focus time will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant,
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

String _formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}


String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'F';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

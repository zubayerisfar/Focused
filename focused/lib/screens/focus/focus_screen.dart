import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/account_provider.dart';
import '../../providers/focus_provider.dart';
import '../../widgets/app_banner_ad_widget.dart';

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
    final recent = provider.sessionHistory.take(5).toList(growable: false);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          _FocusHeader(account: account),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FocusMetric(
                  icon: const FaIcon(FontAwesomeIcons.stopwatch, size: 18),
                  value: _formatDuration(focusedToday),
                  label: 'Today',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FocusMetric(
                  icon: const FaIcon(FontAwesomeIcons.layerGroup, size: 18),
                  value: '$sessionsToday',
                  label: 'Sessions',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FocusMetric(
                  icon: const FaIcon(FontAwesomeIcons.bolt, size: 18),
                  value: _formatDuration(longest),
                  label: 'Longest',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FocusStartCard(provider: provider, focusedToday: focusedToday),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent sessions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (recent.isNotEmpty)
                Text(
                  '${provider.sessionHistory.length} total',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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
          const SizedBox(height: 16),
          const AppBannerAdWidget(),
        ],
      ),
    );
  }
}

class _FocusHeader extends StatelessWidget {
  const _FocusHeader({required this.account});

  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Focus',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: account.photoUrl == null
                  ? null
                  : NetworkImage(account.photoUrl!),
              child: account.photoUrl == null
                  ? Text(
                      _initials(account.displayName),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusStartCard extends StatelessWidget {
  const _FocusStartCard({required this.provider, required this.focusedToday});

  final FocusProvider provider;
  final Duration focusedToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final running = provider.isRunning;
    final paused = provider.isPaused;
    final remaining = Duration(seconds: provider.remainingSeconds);
    final taskName = provider.taskName.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: FaIcon(
                  running ? FontAwesomeIcons.clock : FontAwesomeIcons.bullseye,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running
                          ? (taskName.isEmpty ? 'Focus session' : taskName)
                          : 'Ready to focus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running
                          ? (paused
                                ? 'Paused'
                                : '${_formatClock(remaining)} remaining')
                          : '${_formatDuration(focusedToday)} focused today',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  context.push(running ? '/focus/session' : '/focus/setup'),
              icon: FaIcon(
                running
                    ? FontAwesomeIcons.arrowUpRightFromSquare
                    : FontAwesomeIcons.play,
                size: 16,
              ),
              label: Text(running ? 'Return to session' : 'Start focus'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  const _FocusMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 10, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: IconThemeData(color: scheme.primary),
            child: icon,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  const _SessionHistoryTile({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            context.push('/focus/history/${Uri.encodeComponent(session.id)}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: FaIcon(
                  FontAwesomeIcons.circleCheck,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatDuration(session.actualFocusDuration)} • ${DateFormat('MMM d, h:mm a').format(session.endedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.clockRotateLeft,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Finished sessions will appear here.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

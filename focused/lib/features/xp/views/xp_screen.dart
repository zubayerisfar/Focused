import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/ad_service.dart';

class XpScreen extends StatefulWidget {
  const XpScreen({super.key});

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _watchingAd = false;
  bool _restoringStreak = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<UserStatsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final xp = stats.xpPoints;
    final adsWatched = stats.xpAdsWatchedToday;
    final canWatch = stats.canWatchXpAdToday;
    final canRestore = xp >= UserStatsProvider.xpStreakRestoreCost;
    final adsLeft = UserStatsProvider.xpAdsPerDay - adsWatched;

    return Scaffold(
      appBar: AppBar(
        title: const Text('XP Points'),
        centerTitle: false,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── XP Balance Card ──────────────────────────────────
            _XpBalanceCard(xp: xp, pulseAnimation: _pulseAnimation),
            const SizedBox(height: 24),

            // ── What is XP? ──────────────────────────────────────
            _SectionLabel('What is XP?'),
            const SizedBox(height: 10),
            _InfoCard(
              children: [
                _InfoRow(
                  icon: FontAwesomeIcons.bolt,
                  iconColor: const Color(0xFFFFB300),
                  text:
                      'XP (Experience Points) are earned by watching short reward videos.',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: FontAwesomeIcons.fire,
                  iconColor: Colors.deepOrange,
                  text: 'Use 2,000 XP to restore a broken productivity streak.',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: FontAwesomeIcons.circleCheck,
                  iconColor: Colors.green,
                  text:
                      'Earn 500 XP per ad here · Max ${UserStatsProvider.xpAdsPerDay} ads per day.',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Earn XP Section ───────────────────────────────────
            _SectionLabel('Earn XP Today'),
            const SizedBox(height: 10),
            _EarnXpCard(
              adsWatched: adsWatched,
              adsLeft: adsLeft,
              canWatch: canWatch && !_watchingAd,
              isLoading: _watchingAd,
              onWatchAd: _onWatchAd,
            ),
            const SizedBox(height: 28),

            // ── Streak Restore Section ────────────────────────────
            _SectionLabel('Streak Restore'),
            const SizedBox(height: 10),
            _StreakRestoreCard(
              xp: xp,
              canRestore: canRestore && !_restoringStreak,
              isLoading: _restoringStreak,
              onRestore: _onRestoreStreak,
            ),
          ],
        ),
      ),
    );
  }

  void _onWatchAd() {
    final stats = context.read<UserStatsProvider>();
    if (!stats.canWatchXpAdToday) return;

    setState(() => _watchingAd = true);

    AdService.instance.showRewardedAd(
      onUserEarnedReward: (reward) {
        if (!mounted) return;
        stats.recordXpAdWatched();
        _showSnack('+${UserStatsProvider.xpPerXpPageAd} XP earned! 🎉');
      },
      onAdDismissed: () {
        if (mounted) setState(() => _watchingAd = false);
      },
    );
  }

  void _onRestoreStreak() async {
    final stats = context.read<UserStatsProvider>();
    if (stats.xpPoints < UserStatsProvider.xpStreakRestoreCost) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Restore Streak?'),
          ],
        ),
        content: Text(
          'This will spend 2,000 XP to restore your productivity streak. '
          'You currently have ${stats.xpPoints} XP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spend 2,000 XP'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoringStreak = true);
    final success = await stats.restoreStreakWithXp();
    if (!mounted) return;
    setState(() => _restoringStreak = false);

    if (success) {
      _showSnack('🔥 Streak restored! −2,000 XP spent.');
    } else {
      _showSnack('Not enough XP.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// XP Balance Card
// ─────────────────────────────────────────────────────────────

class _XpBalanceCard extends StatelessWidget {
  final int xp;
  final Animation<double> pulseAnimation;

  const _XpBalanceCard({required this.xp, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFCA28).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCA28),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.bolt,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$xp',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5D4037),
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'XP Points',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF795548),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Earn XP Card
// ─────────────────────────────────────────────────────────────

class _EarnXpCard extends StatelessWidget {
  final int adsWatched;
  final int adsLeft;
  final bool canWatch;
  final bool isLoading;
  final VoidCallback onWatchAd;

  const _EarnXpCard({
    required this.adsWatched,
    required this.adsLeft,
    required this.canWatch,
    required this.isLoading,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = adsWatched / UserStatsProvider.xpAdsPerDay;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.play,
                  color: Color(0xFF1A73E8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Watch a Short Ad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      canWatch
                          ? 'Earn ${UserStatsProvider.xpPerXpPageAd} XP per video'
                          : 'Daily limit reached — come back tomorrow',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Daily progress bar
          Row(
            children: [
              Text(
                '$adsWatched / ${UserStatsProvider.xpAdsPerDay} ads today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (adsLeft > 0)
                Text(
                  '$adsLeft left',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A73E8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: scheme.outlineVariant,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1A73E8)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canWatch ? onWatchAd : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.bolt, size: 14),
              label: Text(
                isLoading
                    ? 'Loading ad…'
                    : canWatch
                    ? 'Watch Ad (+${UserStatsProvider.xpPerXpPageAd} XP)'
                    : 'Limit Reached for Today',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Streak Restore Card
// ─────────────────────────────────────────────────────────────

class _StreakRestoreCard extends StatelessWidget {
  final int xp;
  final bool canRestore;
  final bool isLoading;
  final VoidCallback onRestore;

  const _StreakRestoreCard({
    required this.xp,
    required this.canRestore,
    required this.isLoading,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final xpNeeded = UserStatsProvider.xpStreakRestoreCost;
    final deficit = (xpNeeded - xp).clamp(0, xpNeeded);
    final canAfford = xp >= xpNeeded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: canAfford
            ? const Color(0xFFFFF3E0)
            : scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canAfford
              ? const Color(0xFFFFCA28).withOpacity(0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.fire,
                  color: Colors.deepOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore Streak',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      canAfford
                          ? 'Tap to spend $xpNeeded XP and recover your streak'
                          : 'Need ${deficit} more XP to unlock',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // XP cost display
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.bolt,
                size: 14,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 6),
              Text(
                '$xpNeeded XP required',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                ),
              ),
              const Spacer(),
              Text(
                'Your balance: $xp XP',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),

          if (!canAfford) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: xp / xpNeeded,
                minHeight: 7,
                backgroundColor: scheme.outlineVariant,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canAfford ? Colors.deepOrange : null,
              ),
              onPressed: canRestore ? onRestore : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.fire, size: 14),
              label: Text(
                isLoading
                    ? 'Restoring…'
                    : canAfford
                    ? 'Restore Streak (−2,000 XP)'
                    : 'Not Enough XP',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final FaIconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FaIcon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/ad_service.dart';

class GemsScreen extends StatefulWidget {
  const GemsScreen({super.key});

  @override
  State<GemsScreen> createState() => _GemsScreenState();
}

class _GemsScreenState extends State<GemsScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _watchingAd = false;
  bool _restoringStreak = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Periodic timer to tick remaining cooldown every second
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final stats = context.read<UserStatsProvider>();
      if (stats.isXpAdInCooldown && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<UserStatsProvider>();
    final gems = stats.gems;
    final adsWatched = stats.xpAdsWatchedToday;
    final canWatch = stats.canWatchXpAdToday;
    final canRestore = gems >= UserStatsProvider.gemStreakRestoreCost;
    final isCooldown = stats.isXpAdInCooldown;
    final remainingCooldown = stats.xpAdRemainingCooldown;
    final adsLeft = isCooldown
        ? 0
        : (UserStatsProvider.xpAdsPerDay - adsWatched);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gems & Rewards'),
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
            // ── Gem Balance Card ──────────────────────────────────
            _GemBalanceCard(xp: gems, pulseAnimation: _pulseAnimation),
            const SizedBox(height: 24),

            // ── What are Gems? ──────────────────────────────────────
            _SectionLabel('What are Gems?'),
            const SizedBox(height: 10),
            _InfoCard(
              children: const [
                _InfoRow(
                  icon: FontAwesomeIcons.gem,
                  iconColor: Color(0xFF1CB0F6),
                  text:
                      'Gems are earned by finishing tasks, habits, and watching reward video ads.',
                ),
                SizedBox(height: 12),
                _InfoRow(
                  icon: FontAwesomeIcons.fire,
                  iconColor: Colors.deepOrange,
                  text:
                      'Use 500 Gems to restore a broken or frozen productivity streak.',
                ),
                SizedBox(height: 12),
                _InfoRow(
                  icon: FontAwesomeIcons.circleCheck,
                  iconColor: Colors.green,
                  text:
                      'Earn 100 Gems per ad · Watch 2 ads, then unlock again after a 6-hour break.',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Earn Gems Section ───────────────────────────────────
            _SectionLabel('Earn Gems Today'),
            const SizedBox(height: 10),
            _EarnGemsCard(
              adsWatched: adsWatched,
              adsLeft: adsLeft,
              canWatch: canWatch && !_watchingAd,
              isLoading: _watchingAd,
              isCooldown: isCooldown,
              remainingCooldown: remainingCooldown,
              onWatchAd: _onWatchAd,
            ),
            const SizedBox(height: 28),

            // ── Streak Restore Section ────────────────────
            _SectionLabel('Streak Restore'),
            const SizedBox(height: 10),
            _StreakRestoreCard(
              xp: gems,
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
        _showSnack('+${UserStatsProvider.gemsPerXpPageAd} Gems earned! 🎉');
      },
      onAdDismissed: () {
        if (mounted) setState(() => _watchingAd = false);
      },
    );
  }

  void _onRestoreStreak() async {
    final stats = context.read<UserStatsProvider>();
    if (stats.gems < UserStatsProvider.gemStreakRestoreCost) return;

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
          'This will spend 500 Gems to restore your productivity streak. '
          'You currently have ${stats.gems} Gems.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spend 500 Gems'),
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
      _showSnack('🔥 Streak restored! −500 Gems spent.');
    } else {
      _showSnack('Not enough Gems.');
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
// Gem Balance Card
// ─────────────────────────────────────────────────────────────

class _GemBalanceCard extends StatelessWidget {
  final int xp;
  final Animation<double> pulseAnimation;

  const _GemBalanceCard({required this.xp, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
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
                color: const Color(0xFF0284C7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0369A1).withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icon/gem.svg',
                  width: 44,
                  height: 44,
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
              color: Color(0xFF0C4A6E),
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gems',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0369A1),
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

class _EarnGemsCard extends StatelessWidget {
  final int adsWatched;
  final int adsLeft;
  final bool canWatch;
  final bool isLoading;
  final bool isCooldown;
  final Duration remainingCooldown;
  final VoidCallback onWatchAd;

  const _EarnGemsCard({
    required this.adsWatched,
    required this.adsLeft,
    required this.canWatch,
    required this.isLoading,
    required this.isCooldown,
    required this.remainingCooldown,
    required this.onWatchAd,
  });

  String _formatRemainingCooldown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = isCooldown
        ? 1.0
        : (adsWatched / UserStatsProvider.xpAdsPerDay).clamp(0.0, 1.0);

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
                  color: isCooldown
                      ? Colors.orange.withOpacity(0.12)
                      : const Color(0xFF1A73E8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(
                  isCooldown ? FontAwesomeIcons.clock : FontAwesomeIcons.play,
                  color: isCooldown
                      ? Colors.orange.shade800
                      : const Color(0xFF1A73E8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCooldown ? 'Cooldown Active' : 'Watch a 30s Video Ad',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCooldown
                          ? 'Unlocks in ${_formatRemainingCooldown(remainingCooldown)}'
                          : canWatch
                          ? 'Earn ${UserStatsProvider.xpPerXpPageAd} XP per ad'
                          : 'Watched 2 ads · Break active',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCooldown
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isCooldown
                            ? Colors.orange.shade800
                            : scheme.onSurfaceVariant,
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
                isCooldown
                    ? '2 / 2 ads watched'
                    : '$adsWatched / ${UserStatsProvider.xpAdsPerDay} ads watched',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (!isCooldown && adsLeft > 0)
                Text(
                  '$adsLeft left',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A73E8),
                  ),
                )
              else if (isCooldown)
                Text(
                  '6h Break',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
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
              valueColor: AlwaysStoppedAnimation(
                isCooldown ? Colors.orange.shade600 : const Color(0xFF1A73E8),
              ),
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
                  : FaIcon(
                      isCooldown
                          ? FontAwesomeIcons.lock
                          : FontAwesomeIcons.play,
                      size: 14,
                    ),
              label: Text(
                isLoading
                    ? 'Loading ad…'
                    : isCooldown
                    ? 'Opens in ${_formatRemainingCooldown(remainingCooldown)}'
                    : canWatch
                    ? 'Earn ${UserStatsProvider.gemsPerXpPageAd} Gems'
                    : 'Break in Progress',
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
    final gemCost = UserStatsProvider.gemStreakRestoreCost;
    final deficit = (gemCost - xp).clamp(0, gemCost);
    final canAfford = xp >= gemCost;

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
                          ? 'Tap to spend $gemCost Gems and recover your streak'
                          : 'Need $deficit more Gems to unlock',
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

          // Gem cost display
          Row(
            children: [
              SvgPicture.asset('assets/icon/gem.svg', width: 16, height: 16),
              const SizedBox(width: 6),
              Text(
                '$gemCost Gems required',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                ),
              ),
              const Spacer(),
              Text(
                'Your balance: $xp Gems',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),

          if (!canAfford) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: xp / gemCost,
                minHeight: 7,
                backgroundColor: scheme.outlineVariant,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF0284C7)),
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
                    ? 'Restore Streak (−$gemCost Gems)'
                    : 'Not Enough Gems',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: FaIcon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onSurface.withOpacity(0.88),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

typedef XpScreen = GemsScreen;

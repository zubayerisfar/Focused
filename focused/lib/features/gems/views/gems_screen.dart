import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../streak/providers/user_stats_provider.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/widgets/glass_container.dart';

class GemsScreen extends StatefulWidget {
  const GemsScreen({super.key});

  @override
  State<GemsScreen> createState() => _GemsScreenState();
}

class _GemsScreenState extends State<GemsScreen> {
  bool _watchingAd = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
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
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<UserStatsProvider>();
    final gems = stats.gems;
    final adsWatched = stats.xpAdsWatchedToday;
    final canWatch = stats.canWatchXpAdToday;
    final isCooldown = stats.isXpAdInCooldown;
    final remainingCooldown = stats.xpAdRemainingCooldown;
    final adsLeft = isCooldown
        ? 0
        : (UserStatsProvider.xpAdsPerDay - adsWatched);

    return GlassScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
              // ── Clean Gem Balance Card ────────────────────────────
              _GemBalanceCard(
                gems: gems,
                onWhatAreGemsTap: () => _showWhatAreGemsModal(context),
              ),
              const SizedBox(height: 28),

              // ── Earn Gems Section ─────────────────────────────────
              const _SectionLabel('Earn Gems Today'),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatAreGemsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161D24) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0xFF283845) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SvgPicture.asset('assets/icon/gem.svg', width: 28, height: 28),
                const SizedBox(width: 10),
                Text(
                  'What are Gems?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Gems are productivity rewards earned by staying focused and consistent.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF9BA8B4)
                    : scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _PopupInfoTile(
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF58CC02),
              title: 'Complete Tasks & Habits',
              description:
                  'Earn gems by finishing scheduled tasks and keeping habits consistent.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _PopupInfoTile(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF1CB0F6),
              title: 'Focus Sessions',
              description:
                  'Earn gems every time you complete deep focus sessions without leaving.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _PopupInfoTile(
              icon: Icons.play_circle_outline_rounded,
              iconColor: const Color(0xFFFF9600),
              title: 'Reward Video Ads',
              description:
                  'Earn 100 Gems per ad · Watch 2 ads, then unlock again after a 6-hour break.',
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1CB0F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
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
        _showSnack('+${UserStatsProvider.gemsPerXpPageAd} Gems earned!');
      },
      onAdDismissed: () {
        if (mounted) setState(() => _watchingAd = false);
      },
    );
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
  final int gems;
  final VoidCallback onWhatAreGemsTap;

  const _GemBalanceCard({required this.gems, required this.onWhatAreGemsTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return GlassContainer(
      width: double.infinity,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          SvgPicture.asset('assets/icon/gem.svg', width: 52, height: 52),
          const SizedBox(height: 14),
          Text(
            '$gems',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : scheme.onSurface,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Gems',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8B949E) : scheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          // Clickable "What are Gems?" text
          InkWell(
            onTap: onWhatAreGemsTap,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Color(0xFF1CB0F6),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'What are Gems?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1CB0F6),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFF1CB0F6),
                  ),
                ],
              ),
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

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCooldown
                      ? Colors.orange.withValues(alpha: 0.12)
                      : const Color(0xFF1A73E8).withValues(alpha: 0.12),
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
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
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

class _PopupInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isDark;

  const _PopupInfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202A34) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3947) : const Color(0xFFEEF0F2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9BA8B4) : Colors.black54,
                    height: 1.35,
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

typedef XpScreen = GemsScreen;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/ad_service.dart';

class ProductivityInsightCard extends StatefulWidget {
  const ProductivityInsightCard({super.key});

  @override
  State<ProductivityInsightCard> createState() =>
      _ProductivityInsightCardState();
}

class _ProductivityInsightCardState extends State<ProductivityInsightCard> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final cardBgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF132840), Color(0xFF1A1F30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final cardBorderColor = _unlocked
        ? const Color(0xFF10B981).withValues(alpha: 0.5)
        : (isDark
              ? const Color(0xFF1CB0F6).withValues(alpha: 0.40)
              : const Color(0xFF1CB0F6).withValues(alpha: 0.32));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: cardBgGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF1CB0F6,
            ).withValues(alpha: isDark ? 0.20 : 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9600), Color(0xFFFF5722)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9600).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Productivity Insight',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
              if (_unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Unlocked',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          if (!_unlocked) ...[
            const SizedBox(height: 6),
            Text(
              'Unlock your daily focus velocity & peak productivity hours.',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 12.5,
                color: isDark
                    ? const Color(0xFF8FA3B0)
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1CB0F6), Color(0xFF0075FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1CB0F6).withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    AdService.instance.showRewardedAd(
                      onUserEarnedReward: (reward) {
                        if (mounted) {
                          setState(() => _unlocked = true);
                          _openDetailedReport(context);
                        }
                      },
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Watch ad to unlock insight',
                        style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openDetailedReport(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Peak Focus: 9:00 AM – 11:30 AM',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF58CC02,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '87% Focus',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF58CC02),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildVelocityBar('8a', 0.45, false, isDark, scheme),
                        _buildVelocityBar('9a', 0.88, false, isDark, scheme),
                        _buildVelocityBar('10a', 0.96, true, isDark, scheme),
                        _buildVelocityBar('11a', 0.82, false, isDark, scheme),
                        _buildVelocityBar('12p', 0.35, false, isDark, scheme),
                        _buildVelocityBar('2p', 0.60, false, isDark, scheme),
                        _buildVelocityBar('4p', 0.72, false, isDark, scheme),
                        _buildVelocityBar('8p', 0.40, false, isDark, scheme),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetailedReport(BuildContext context) {
    context.push('/wellbeing/focus-interruptions');
  }

  Widget _buildVelocityBar(
    String label,
    double heightPercent,
    bool isPeak,
    bool isDark,
    ColorScheme scheme,
  ) {
    const double maxHeight = 46.0;
    final barHeight = maxHeight * heightPercent;
    final color = isPeak
        ? const Color(0xFFFF9600)
        : (heightPercent >= 0.7
              ? const Color(0xFF1CB0F6)
              : const Color(0xFF9E9E9E).withValues(alpha: 0.4));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPeak)
          const Text(
            '★',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFFFF9600),
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const SizedBox(height: 12),
        Container(
          width: 20,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w500,
            color: isPeak
                ? (isDark ? Colors.white : Colors.black)
                : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _unlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productivity Insight',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : scheme.onSurface,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_unlocked)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1CB0F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  AdService.instance.showRewardedAd(
                    onUserEarnedReward: (reward) {
                      if (mounted) {
                        setState(() => _unlocked = true);
                        _openDetailedReport(context);
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                label: const Text(
                  'Watch ad to unlock insight',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            )
          else
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

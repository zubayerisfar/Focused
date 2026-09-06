import 'package:flutter/material.dart';

import '../models/achievement_badge.dart';

class AchievementBadgeArt extends StatelessWidget {
  const AchievementBadgeArt({
    super.key,
    required this.badge,
    this.size = 84,
    this.showLock = true,
  });

  final AchievementBadge badge;
  final double size;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    final child = Image.asset(
      badge.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        final days = badge.target.toInt();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: badge.category == AchievementBadgeCategory.streak
                  ? (badge.achieved
                        ? [const Color(0xFFFF9600), const Color(0xFFFF4B4B)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)])
                  : (badge.achieved
                        ? [const Color(0xFF1CB0F6), const Color(0xFF2B70C9)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)]),
            ),
            boxShadow: badge.achieved
                ? [
                    BoxShadow(
                      color:
                          (badge.category == AchievementBadgeCategory.streak
                                  ? const Color(0xFFFF4B4B)
                                  : const Color(0xFF1CB0F6))
                              .withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                badge.category == AchievementBadgeCategory.streak
                    ? Icons.local_fire_department_rounded
                    : (badge.category == AchievementBadgeCategory.friendship
                          ? Icons.people_alt_rounded
                          : Icons.workspace_premium_rounded),
                size: size * 0.28,
                color: Colors.white,
              ),
              const SizedBox(height: 1),
              Text(
                '$days',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );

    final art = badge.achieved
        ? child
        : ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.grey,
              BlendMode.saturation,
            ),
            child: child,
          );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: badge.achieved ? 1 : 0.28, child: art),
          if (!badge.achieved && showLock)
            Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: size * 0.23,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

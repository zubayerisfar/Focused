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
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          alignment: Alignment.center,
          child: Icon(
            badge.category == AchievementBadgeCategory.streak
                ? Icons.local_fire_department_rounded
                : Icons.workspace_premium_rounded,
            size: size * 0.46,
            color: badge.achieved
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
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

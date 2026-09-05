class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.assetPath,
    required this.category,
    required this.achieved,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final String assetPath;
  final AchievementBadgeCategory category;
  final bool achieved;
  final double progress;
  final double target;

  double get progressRatio {
    if (target <= 0) return achieved ? 1 : 0;
    return (progress / target).clamp(0.0, 1.0).toDouble();
  }
}

enum AchievementBadgeCategory {
  streak,
  focusSession,
  totalFocus,
}

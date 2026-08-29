class FocusAnalysisCoverage {
  final int totalSessions;
  final int analyzedSessions;

  const FocusAnalysisCoverage({
    required this.totalSessions,
    required this.analyzedSessions,
  });

  int get missingSessions => totalSessions - analyzedSessions;

  double get ratio {
    if (totalSessions == 0) {
      return 1;
    }
    return analyzedSessions / totalSessions;
  }

  int get percent => (ratio * 100).round().clamp(0, 100).toInt();

  bool get isComplete => missingSessions == 0;

  bool get isSufficientForComparison {
    if (totalSessions == 0) {
      return true;
    }
    return ratio >= 0.80;
  }
}

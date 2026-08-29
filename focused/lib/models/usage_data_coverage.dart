import 'usage_data_provenance.dart';

class UsageCoverageSample {
  final UsageDataProvenance provenance;
  final bool completeDay;

  const UsageCoverageSample({
    required this.provenance,
    required this.completeDay,
  });
}

class UsageDataCoverage {
  final int totalDays;
  final int measuredDays;
  final int completeDays;
  final int partialDays;
  final int liveAndroidDays;
  final int focusedStorageDays;
  final int androidHistoryDays;
  final int missingDays;

  const UsageDataCoverage({
    required this.totalDays,
    required this.measuredDays,
    required this.completeDays,
    required this.partialDays,
    required this.liveAndroidDays,
    required this.focusedStorageDays,
    required this.androidHistoryDays,
    required this.missingDays,
  });

  /// Compatibility helper for callers that only know provenance. Every
  /// measured value is treated as a complete day. New analytics code should
  /// prefer [fromMeasurements].
  factory UsageDataCoverage.fromProvenance(
    Iterable<UsageDataProvenance> values,
  ) {
    return UsageDataCoverage.fromMeasurements(
      values.map(
        (value) => UsageCoverageSample(
          provenance: value,
          completeDay: value.measured,
        ),
      ),
    );
  }

  factory UsageDataCoverage.fromMeasurements(
    Iterable<UsageCoverageSample> values,
  ) {
    var total = 0;
    var measured = 0;
    var complete = 0;
    var partial = 0;
    var live = 0;
    var stored = 0;
    var history = 0;
    var missing = 0;

    for (final value in values) {
      total++;
      switch (value.provenance) {
        case UsageDataProvenance.liveAndroid:
          measured++;
          live++;
          if (value.completeDay) {
            complete++;
          } else {
            partial++;
          }
          break;
        case UsageDataProvenance.focusedStorage:
          measured++;
          stored++;
          if (value.completeDay) {
            complete++;
          } else {
            partial++;
          }
          break;
        case UsageDataProvenance.androidHistory:
          measured++;
          history++;
          if (value.completeDay) {
            complete++;
          } else {
            partial++;
          }
          break;
        case UsageDataProvenance.missing:
          missing++;
          break;
      }
    }

    return UsageDataCoverage(
      totalDays: total,
      measuredDays: measured,
      completeDays: complete,
      partialDays: partial,
      liveAndroidDays: live,
      focusedStorageDays: stored,
      androidHistoryDays: history,
      missingDays: missing,
    );
  }

  double get ratio {
    if (totalDays <= 0) {
      return 0;
    }
    return measuredDays / totalDays;
  }

  double get completeRatio {
    if (totalDays <= 0) {
      return 0;
    }
    return completeDays / totalDays;
  }

  int get percent => (ratio * 100).round().clamp(0, 100).toInt();

  bool get isComplete =>
      totalDays > 0 && missingDays == 0 && partialDays == 0;

  /// A visual trend needs enough complete observations to represent both the
  /// older and newer portions of the selected range. Today's partial value is
  /// shown in the graph but never treated as a full historical day.
  bool get isSufficientForTrend {
    if (totalDays < 4 || completeDays < 4) {
      return false;
    }
    return completeDays / totalDays >= 0.60;
  }

  /// Seven-day comparisons are deliberately stricter. Five complete days in
  /// each seven-day window is the minimum accepted coverage. A partial current
  /// day does not become a fake full day just because Usage Access is working.
  bool get isSufficientForPeriodComparison {
    if (totalDays <= 0) {
      return false;
    }

    if (totalDays == 7) {
      return completeDays >= 5;
    }

    return completeDays >= 3 && completeRatio >= 0.70;
  }

  String get qualityLabel {
    if (isComplete) {
      return 'Complete';
    }
    if (completeRatio >= 0.70) {
      return 'Good';
    }
    if (completeRatio >= 0.50) {
      return 'Partial';
    }
    return 'Insufficient';
  }
}

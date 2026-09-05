enum UsageDataProvenance {
  /// Read directly from Android for the current day during this app runtime.
  liveAndroid,

  /// Read from Focused's local Hive snapshot store.
  focusedStorage,

  /// Backfilled from Android UsageStats for a closed/recent historical day.
  androidHistory,

  /// No trustworthy snapshot exists for this day.
  missing,
}

extension UsageDataProvenanceX on UsageDataProvenance {
  bool get measured => this != UsageDataProvenance.missing;

  String get label {
    switch (this) {
      case UsageDataProvenance.liveAndroid:
        return 'Measured today';
      case UsageDataProvenance.focusedStorage:
        return 'Stored by Focused';
      case UsageDataProvenance.androidHistory:
        return 'Android history';
      case UsageDataProvenance.missing:
        return 'No data';
    }
  }
}

import '../models/app_usage_record.dart';

enum UsageEventKind {
  foreground,
  background,
  screenInteractive,
  screenNonInteractive,
  deviceShutdown,
  deviceStartup,
}

class UsageEventPoint {
  final String? packageName;
  final String? className;
  final DateTime timestamp;
  final UsageEventKind kind;

  const UsageEventPoint({
    required this.packageName,
    required this.className,
    required this.timestamp,
    required this.kind,
  });
}

class UsageEventNormalizer {
  const UsageEventNormalizer();

  List<AppUsageRecord> normalize({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<UsageEventPoint> events,
  }) {
    if (!rangeEnd.isAfter(rangeStart)) {
      return const [];
    }

    final ordered =
        events.where((event) => !event.timestamp.isAfter(rangeEnd)).toList()
          ..sort(_compareEvents);

    final activePackages = <String, DateTime>{};
    final rawRecords = <AppUsageRecord>[];

    void closePackage(String packageName, DateTime end) {
      final startedAt = activePackages.remove(packageName);
      if (startedAt == null || !end.isAfter(startedAt)) {
        return;
      }

      final clippedStart = startedAt.isAfter(rangeStart)
          ? startedAt
          : rangeStart;
      final clippedEnd = end.isBefore(rangeEnd) ? end : rangeEnd;

      if (!clippedEnd.isAfter(clippedStart)) {
        return;
      }

      rawRecords.add(
        AppUsageRecord(
          appId: packageName,
          appName: packageName,
          startTime: clippedStart,
          endTime: clippedEnd,
        ),
      );
    }

    void closeAll(DateTime end) {
      final packages = activePackages.keys.toList(growable: false);
      for (final pkg in packages) {
        closePackage(pkg, end);
      }
      activePackages.clear();
    }

    for (final event in ordered) {
      if (event.timestamp.isAfter(rangeEnd)) {
        break;
      }

      switch (event.kind) {
        case UsageEventKind.foreground:
          final packageName = event.packageName?.trim();
          if (packageName == null || packageName.isEmpty) {
            continue;
          }

          // In Android, only one application is in the user's active foreground.
          // When a new package enters foreground, close all other packages at this timestamp.
          final otherPackages = activePackages.keys
              .where((pkg) => pkg != packageName)
              .toList(growable: false);
          for (final other in otherPackages) {
            closePackage(other, event.timestamp);
          }

          // If this package was not already marked active, record its start time.
          activePackages.putIfAbsent(packageName, () => event.timestamp);
          break;

        case UsageEventKind.background:
          final packageName = event.packageName?.trim();
          if (packageName == null || packageName.isEmpty) {
            continue;
          }

          closePackage(packageName, event.timestamp);
          break;

        case UsageEventKind.screenNonInteractive:
        case UsageEventKind.deviceShutdown:
          closeAll(event.timestamp);
          break;

        case UsageEventKind.deviceStartup:
          // Never bridge a foreground interval across a runtime/device restart.
          activePackages.clear();
          break;

        case UsageEventKind.screenInteractive:
          // Screen-on does not tell us which app is in the foreground. We wait
          // for the next activity foreground event instead of guessing.
          break;
      }
    }

    // Any package still active at query end is considered foreground until the
    // end boundary. The end boundary is normally DateTime.now() for today.
    closeAll(rangeEnd);

    return _mergePerPackage(rawRecords);
  }

  int _compareEvents(UsageEventPoint a, UsageEventPoint b) {
    final timeCompare = a.timestamp.compareTo(b.timestamp);
    if (timeCompare != 0) {
      return timeCompare;
    }

    // At an identical timestamp, close old state before opening new state.
    return _eventPriority(a.kind).compareTo(_eventPriority(b.kind));
  }

  int _eventPriority(UsageEventKind kind) {
    switch (kind) {
      case UsageEventKind.deviceShutdown:
      case UsageEventKind.deviceStartup:
      case UsageEventKind.screenNonInteractive:
      case UsageEventKind.background:
        return 0;
      case UsageEventKind.screenInteractive:
        return 1;
      case UsageEventKind.foreground:
        return 2;
    }
  }

  List<AppUsageRecord> _mergePerPackage(List<AppUsageRecord> records) {
    final byPackage = <String, List<AppUsageRecord>>{};

    for (final record in records) {
      byPackage.putIfAbsent(record.appId, () => []).add(record);
    }

    final merged = <AppUsageRecord>[];

    for (final entry in byPackage.entries) {
      final packageRecords = entry.value
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (packageRecords.isEmpty) {
        continue;
      }

      var currentStart = packageRecords.first.startTime;
      var currentEnd = packageRecords.first.endTime;

      for (var i = 1; i < packageRecords.length; i++) {
        final next = packageRecords[i];

        if (!next.startTime.isAfter(currentEnd)) {
          if (next.endTime.isAfter(currentEnd)) {
            currentEnd = next.endTime;
          }
          continue;
        }

        merged.add(
          AppUsageRecord(
            appId: entry.key,
            appName: entry.key,
            startTime: currentStart,
            endTime: currentEnd,
          ),
        );

        currentStart = next.startTime;
        currentEnd = next.endTime;
      }

      merged.add(
        AppUsageRecord(
          appId: entry.key,
          appName: entry.key,
          startTime: currentStart,
          endTime: currentEnd,
        ),
      );
    }

    merged.sort((a, b) => a.startTime.compareTo(b.startTime));
    return List.unmodifiable(merged);
  }
}

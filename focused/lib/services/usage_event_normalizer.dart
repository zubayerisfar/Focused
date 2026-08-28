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

    final ordered = events
        .where((event) => !event.timestamp.isAfter(rangeEnd))
        .toList()
      ..sort(_compareEvents);

    final activeComponents = <String, _ActiveComponent>{};
    final rawRecords = <AppUsageRecord>[];

    void closeComponent(String key, DateTime end) {
      final active = activeComponents.remove(key);
      if (active == null || !end.isAfter(active.startedAt)) {
        return;
      }

      final clippedStart = active.startedAt.isAfter(rangeStart)
          ? active.startedAt
          : rangeStart;
      final clippedEnd = end.isBefore(rangeEnd) ? end : rangeEnd;

      if (!clippedEnd.isAfter(clippedStart)) {
        return;
      }

      rawRecords.add(
        AppUsageRecord(
          appId: active.packageName,
          appName: active.packageName,
          startTime: clippedStart,
          endTime: clippedEnd,
        ),
      );
    }

    void closeAll(DateTime end) {
      final keys = activeComponents.keys.toList(growable: false);
      for (final key in keys) {
        closeComponent(key, end);
      }
      activeComponents.clear();
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

          final key = _componentKey(packageName, event.className);
          activeComponents.putIfAbsent(
            key,
            () => _ActiveComponent(
              packageName: packageName,
              startedAt: event.timestamp,
            ),
          );
          break;

        case UsageEventKind.background:
          final packageName = event.packageName?.trim();
          if (packageName == null || packageName.isEmpty) {
            continue;
          }

          final exactKey = _componentKey(packageName, event.className);
          if (activeComponents.containsKey(exactKey)) {
            closeComponent(exactKey, event.timestamp);
            continue;
          }

          // Some Android builds omit class names on one side of a lifecycle
          // transition. If exactly one component for this package is active,
          // it is safe to close that component rather than losing the interval.
          final matchingKeys = activeComponents.entries
              .where((entry) => entry.value.packageName == packageName)
              .map((entry) => entry.key)
              .toList(growable: false);

          if (matchingKeys.length == 1) {
            closeComponent(matchingKeys.single, event.timestamp);
          }
          break;

        case UsageEventKind.screenNonInteractive:
        case UsageEventKind.deviceShutdown:
          closeAll(event.timestamp);
          break;

        case UsageEventKind.deviceStartup:
          // Never bridge a foreground interval across a runtime/device restart.
          activeComponents.clear();
          break;

        case UsageEventKind.screenInteractive:
          // Screen-on does not tell us which app is in the foreground. We wait
          // for the next activity foreground event instead of guessing.
          break;
      }
    }

    // Any activity still open at query end is considered foreground until the
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

  String _componentKey(String packageName, String? className) {
    final normalizedClass = className?.trim();
    if (normalizedClass == null || normalizedClass.isEmpty) {
      return packageName;
    }

    return '$packageName::$normalizedClass';
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

class _ActiveComponent {
  final String packageName;
  final DateTime startedAt;

  const _ActiveComponent({
    required this.packageName,
    required this.startedAt,
  });
}

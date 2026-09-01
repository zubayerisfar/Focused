import 'usage_event_normalizer.dart';

class AppOpenTransition {
  const AppOpenTransition({required this.appId, required this.timestamp});

  final String appId;
  final DateTime timestamp;
}

class AppOpenCounter {
  const AppOpenCounter();

  List<AppOpenTransition> count({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<UsageEventPoint> events,
    Set<String> ignoredPackages = const <String>{},
  }) {
    if (!rangeEnd.isAfter(rangeStart)) return const <AppOpenTransition>[];

    final ordered = events.toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    String? lastForegroundPackage;
    final openings = <AppOpenTransition>[];

    for (final event in ordered) {
      if (!event.timestamp.isBefore(rangeEnd)) continue;
      if (event.kind == UsageEventKind.deviceStartup) {
        lastForegroundPackage = null;
        continue;
      }
      if (event.kind != UsageEventKind.foreground) continue;

      final packageName = event.packageName?.trim();
      if (packageName == null ||
          packageName.isEmpty ||
          ignoredPackages.contains(packageName)) {
        continue;
      }

      final changedPackage = packageName != lastForegroundPackage;
      lastForegroundPackage = packageName;
      if (changedPackage && !event.timestamp.isBefore(rangeStart)) {
        openings.add(
          AppOpenTransition(appId: packageName, timestamp: event.timestamp),
        );
      }
    }

    return List<AppOpenTransition>.unmodifiable(openings);
  }
}

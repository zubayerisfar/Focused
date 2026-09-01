import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/app_open_counter.dart';
import 'package:focused/services/usage_event_normalizer.dart';

void main() {
  const counter = AppOpenCounter();
  final start = DateTime(2026, 9, 1, 8);
  final end = DateTime(2026, 9, 1, 12);

  UsageEventPoint event(
    String? package,
    int minute,
    UsageEventKind kind, {
    String? className,
  }) {
    return UsageEventPoint(
      packageName: package,
      className: className,
      timestamp: start.add(Duration(minutes: minute)),
      kind: kind,
    );
  }

  test('counts only foreground transitions from a different package', () {
    final result = counter.count(
      rangeStart: start,
      rangeEnd: end,
      events: [
        event('launcher', 0, UsageEventKind.foreground),
        event('youtube', 1, UsageEventKind.foreground, className: 'Home'),
        event('youtube', 2, UsageEventKind.foreground, className: 'Video'),
        event('chrome', 10, UsageEventKind.foreground),
        event('youtube', 20, UsageEventKind.foreground),
      ],
    );

    expect(result.map((item) => item.appId).toList(), [
      'launcher',
      'youtube',
      'chrome',
      'youtube',
    ]);
    expect(result.where((item) => item.appId == 'youtube').length, 2);
  });

  test('lookback foreground establishes boundary state without being counted', () {
    final result = counter.count(
      rangeStart: start,
      rangeEnd: end,
      events: [
        UsageEventPoint(
          packageName: 'youtube',
          className: null,
          timestamp: start.subtract(const Duration(minutes: 2)),
          kind: UsageEventKind.foreground,
        ),
        event('youtube', 1, UsageEventKind.foreground),
        event('chrome', 5, UsageEventKind.foreground),
      ],
    );

    expect(result.map((item) => item.appId).toList(), ['chrome']);
  });

  test('device startup resets transition state', () {
    final result = counter.count(
      rangeStart: start,
      rangeEnd: end,
      events: [
        event('youtube', 1, UsageEventKind.foreground),
        event(null, 5, UsageEventKind.deviceStartup),
        event('youtube', 6, UsageEventKind.foreground),
      ],
    );

    expect(result.where((item) => item.appId == 'youtube').length, 2);
  });

  test('ignored packages are not counted', () {
    final result = counter.count(
      rangeStart: start,
      rangeEnd: end,
      ignoredPackages: const {'android'},
      events: [
        event('android', 1, UsageEventKind.foreground),
        event('youtube', 2, UsageEventKind.foreground),
      ],
    );

    expect(result.map((item) => item.appId).toList(), ['youtube']);
  });
}

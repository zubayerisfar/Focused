import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/usage_event_normalizer.dart';

void main() {
  const normalizer = UsageEventNormalizer();

  UsageEventPoint event({
    required int hour,
    required int minute,
    required UsageEventKind kind,
    String? packageName = 'com.example.app',
    String? className = 'MainActivity',
  }) {
    return UsageEventPoint(
      packageName: packageName,
      className: className,
      timestamp: DateTime(2026, 8, 28, hour, minute),
      kind: kind,
    );
  }

  test('pairs foreground and background into one interval', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 12),
      events: [
        event(hour: 10, minute: 15, kind: UsageEventKind.foreground),
        event(hour: 10, minute: 45, kind: UsageEventKind.background),
      ],
    );

    expect(records, hasLength(1));
    expect(records.single.startTime, DateTime(2026, 8, 28, 10, 15));
    expect(records.single.endTime, DateTime(2026, 8, 28, 10, 45));
  });

  test('clips an app already foreground before requested range', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 12),
      events: [
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'MainActivity',
          timestamp: DateTime(2026, 8, 28, 9, 55),
          kind: UsageEventKind.foreground,
        ),
        event(hour: 10, minute: 10, kind: UsageEventKind.background),
      ],
    );

    expect(records.single.startTime, DateTime(2026, 8, 28, 10));
    expect(records.single.endTime, DateTime(2026, 8, 28, 10, 10));
  });

  test('screen non-interactive closes foreground activity', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 12),
      events: [
        event(hour: 10, minute: 5, kind: UsageEventKind.foreground),
        event(
          hour: 10,
          minute: 25,
          kind: UsageEventKind.screenNonInteractive,
          packageName: null,
          className: null,
        ),
      ],
    );

    expect(records, hasLength(1));
    expect(records.single.endTime, DateTime(2026, 8, 28, 10, 25));
  });

  test('open foreground interval closes at query end', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 10, 30),
      events: [
        event(hour: 10, minute: 10, kind: UsageEventKind.foreground),
      ],
    );

    expect(records.single.endTime, DateTime(2026, 8, 28, 10, 30));
  });

  test('multiple activities in same package merge into unique app interval', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 11),
      events: [
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'A',
          timestamp: DateTime(2026, 8, 28, 10),
          kind: UsageEventKind.foreground,
        ),
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'B',
          timestamp: DateTime(2026, 8, 28, 10, 10),
          kind: UsageEventKind.foreground,
        ),
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'A',
          timestamp: DateTime(2026, 8, 28, 10, 20),
          kind: UsageEventKind.background,
        ),
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'B',
          timestamp: DateTime(2026, 8, 28, 10, 30),
          kind: UsageEventKind.background,
        ),
      ],
    );

    expect(records, hasLength(1));
    expect(records.single.startTime, DateTime(2026, 8, 28, 10));
    expect(records.single.endTime, DateTime(2026, 8, 28, 10, 30));
  });

  test('different packages remain separate', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 11),
      events: [
        UsageEventPoint(
          packageName: 'com.first',
          className: 'Main',
          timestamp: DateTime(2026, 8, 28, 10),
          kind: UsageEventKind.foreground,
        ),
        UsageEventPoint(
          packageName: 'com.first',
          className: 'Main',
          timestamp: DateTime(2026, 8, 28, 10, 15),
          kind: UsageEventKind.background,
        ),
        UsageEventPoint(
          packageName: 'com.second',
          className: 'Main',
          timestamp: DateTime(2026, 8, 28, 10, 15),
          kind: UsageEventKind.foreground,
        ),
        UsageEventPoint(
          packageName: 'com.second',
          className: 'Main',
          timestamp: DateTime(2026, 8, 28, 10, 30),
          kind: UsageEventKind.background,
        ),
      ],
    );

    expect(records, hasLength(2));
    expect(records[0].appId, 'com.first');
    expect(records[1].appId, 'com.second');
  });

  test('device startup clears an unmatched pre-restart foreground state', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 11),
      events: [
        UsageEventPoint(
          packageName: 'com.example.app',
          className: 'Main',
          timestamp: DateTime(2026, 8, 28, 9, 50),
          kind: UsageEventKind.foreground,
        ),
        event(
          hour: 10,
          minute: 0,
          kind: UsageEventKind.deviceStartup,
          packageName: null,
          className: null,
        ),
      ],
    );

    expect(records, isEmpty);
  });

  test('unmatched background event is ignored rather than inventing usage', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 10),
      rangeEnd: DateTime(2026, 8, 28, 11),
      events: [
        event(hour: 10, minute: 20, kind: UsageEventKind.background),
      ],
    );

    expect(records, isEmpty);
  });

  test('invalid query range returns empty list', () {
    final records = normalizer.normalize(
      rangeStart: DateTime(2026, 8, 28, 11),
      rangeEnd: DateTime(2026, 8, 28, 10),
      events: const [],
    );

    expect(records, isEmpty);
  });
}

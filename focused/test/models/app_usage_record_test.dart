import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/app_usage_record.dart';

void main() {
  test('serializes and restores a usage record', () {
    final record = AppUsageRecord(
      appId: 'com.instagram.android',
      appName: 'Instagram',
      startTime: DateTime(2026, 8, 28, 10),
      endTime: DateTime(2026, 8, 28, 10, 15),
    );

    final restored = AppUsageRecord.fromMap(record.toMap());

    expect(restored.appId, record.appId);
    expect(restored.appName, record.appName);
    expect(restored.startTime, record.startTime);
    expect(restored.endTime, record.endTime);
    expect(restored.duration, const Duration(minutes: 15));
  });

  test('rejects invalid interval during restore', () {
    expect(
      () => AppUsageRecord.fromMap({
        'appId': 'x',
        'appName': 'X',
        'startTime': DateTime(2026, 8, 28, 10).toIso8601String(),
        'endTime': DateTime(2026, 8, 28, 9).toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test('overlaps uses half-open interval behavior', () {
    final record = AppUsageRecord(
      appId: 'x',
      appName: 'X',
      startTime: DateTime(2026, 8, 28, 10),
      endTime: DateTime(2026, 8, 28, 11),
    );

    expect(
      record.overlaps(
        DateTime(2026, 8, 28, 10, 30),
        DateTime(2026, 8, 28, 11, 30),
      ),
      isTrue,
    );
    expect(
      record.overlaps(
        DateTime(2026, 8, 28, 11),
        DateTime(2026, 8, 28, 12),
      ),
      isFalse,
    );
  });
}

import 'package:hive_ce/hive_ce.dart';

import '../models/app_usage_record.dart';

class UsageDaySnapshot {
  final DateTime day;
  final DateTime updatedAt;
  final List<AppUsageRecord> records;

  const UsageDaySnapshot({
    required this.day,
    required this.updatedAt,
    required this.records,
  });
}

abstract class UsageRecordStore {
  Future<void> init();

  Future<UsageDaySnapshot?> loadDay(DateTime day);

  Future<void> saveDay(
    DateTime day,
    List<AppUsageRecord> records, {
    DateTime? updatedAt,
  });

  Future<void> deleteDay(DateTime day);
}

class UsageRecordStorageService implements UsageRecordStore {
  static const String _boxName = 'focused_usage_records_v1';
  static const int _schemaVersion = 1;

  Box<dynamic>? _box;

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requiredBox {
    final box = _box;
    if (box == null) {
      throw StateError('UsageRecordStorageService.init() must be called first.');
    }
    return box;
  }

  @override
  Future<UsageDaySnapshot?> loadDay(DateTime day) async {
    final key = _dayKey(day);
    final box = _requiredBox;

    if (!box.containsKey(key)) {
      return null;
    }

    final raw = box.get(key);
    if (raw is! Map) {
      return null;
    }

    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion is! num || schemaVersion.toInt() != _schemaVersion) {
      return null;
    }

    final updatedAtRaw = raw['updatedAt'];
    final recordsRaw = raw['records'];

    final updatedAt = updatedAtRaw is String
        ? DateTime.tryParse(updatedAtRaw)
        : null;

    if (updatedAt == null || recordsRaw is! List) {
      return null;
    }

    final records = <AppUsageRecord>[];

    for (final item in recordsRaw) {
      if (item is! Map) {
        continue;
      }

      try {
        records.add(AppUsageRecord.fromMap(item));
      } catch (_) {
        // Ignore a malformed historical row rather than making the entire
        // wellbeing system unreadable. The next successful refresh replaces
        // this day's snapshot with clean data.
      }
    }

    records.sort((a, b) => a.startTime.compareTo(b.startTime));

    return UsageDaySnapshot(
      day: _startOfDay(day),
      updatedAt: updatedAt,
      records: List.unmodifiable(records),
    );
  }

  @override
  Future<void> saveDay(
    DateTime day,
    List<AppUsageRecord> records, {
    DateTime? updatedAt,
  }) async {
    final normalizedDay = _startOfDay(day);
    final dayEnd = DateTime(
      normalizedDay.year,
      normalizedDay.month,
      normalizedDay.day + 1,
    );

    final validRecords = records
        .where(
          (record) =>
              record.endTime.isAfter(record.startTime) &&
              record.startTime.isBefore(dayEnd) &&
              record.endTime.isAfter(normalizedDay),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    await _requiredBox.put(
      _dayKey(day),
      {
        'schemaVersion': _schemaVersion,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        'records': validRecords.map((record) => record.toMap()).toList(),
      },
    );
  }

  @override
  Future<void> deleteDay(DateTime day) async {
    await _requiredBox.delete(_dayKey(day));
  }

  String _dayKey(DateTime day) {
    final normalized = _startOfDay(day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final date = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$date';
  }

  DateTime _startOfDay(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }
}

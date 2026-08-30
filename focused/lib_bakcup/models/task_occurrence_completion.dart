class TaskOccurrenceCompletion {
  final String taskId;
  final DateTime occurrenceDate;
  final DateTime completedAt;

  TaskOccurrenceCompletion({
    required String taskId,
    required DateTime occurrenceDate,
    required this.completedAt,
  })  : taskId = taskId.trim(),
        occurrenceDate = _dateOnlyLocal(occurrenceDate) {
    if (this.taskId.isEmpty) {
      throw ArgumentError('Task ID cannot be empty.');
    }
  }

  String get storageKey => buildStorageKey(taskId, occurrenceDate);

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'taskId': taskId,
      'occurrenceDate': occurrenceDate.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory TaskOccurrenceCompletion.fromMap(Map<dynamic, dynamic> map) {
    final taskId = map['taskId'];
    if (taskId is! String || taskId.trim().isEmpty) {
      throw const FormatException(
        'Occurrence completion taskId is missing or invalid.',
      );
    }

    return TaskOccurrenceCompletion(
      taskId: taskId,
      occurrenceDate: _requiredDate(map, 'occurrenceDate'),
      completedAt: _requiredDate(map, 'completedAt'),
    );
  }

  static String buildStorageKey(
    String taskId,
    DateTime occurrenceDate,
  ) {
    final day = _dateOnlyLocal(occurrenceDate);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '$taskId|'
        '${day.year.toString().padLeft(4, '0')}-'
        '${twoDigits(day.month)}-'
        '${twoDigits(day.day)}';
  }
}

DateTime _requiredDate(
  Map<dynamic, dynamic> map,
  String key,
) {
  final raw = map[key];
  if (raw is! String) {
    throw FormatException('Missing or invalid $key.');
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Invalid date: $raw');
  }

  return parsed;
}

DateTime _dateOnlyLocal(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;

  return DateTime(
    local.year,
    local.month,
    local.day,
  );
}

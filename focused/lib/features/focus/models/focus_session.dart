import 'focus_block.dart';

class FocusInterval {
  final DateTime startTime;
  final DateTime endTime;

  const FocusInterval({
    required this.startTime,
    required this.endTime,
  });

  Duration get duration {
    return endTime.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory FocusInterval.fromMap(Map<dynamic, dynamic> map) {
    final startTime = _requiredDate(map, 'startTime');
    final endTime = _requiredDate(map, 'endTime');

    if (!endTime.isAfter(startTime)) {
      throw const FormatException(
        'Focus interval end must be after start.',
      );
    }

    return FocusInterval(
      startTime: startTime,
      endTime: endTime,
    );
  }
}

class FocusSession {
  final String id;

  /// Snapshot link to the task that started the session.
  ///
  /// Historical sessions remain valid even if the task is deleted later.
  final String? taskId;

  /// Snapshot of the task title at session start.
  final String taskName;

  /// Local calendar occurrence that this session belongs to.
  ///
  /// This is explicit for recurring tasks so a session can never be
  /// accidentally attributed to a different occurrence later.
  final DateTime? taskOccurrenceDate;

  /// Snapshot of the planned calendar window at session start.
  /// Historical schedule-adherence analytics therefore survive later edits.
  final DateTime? taskScheduledStart;
  final DateTime? taskScheduledEnd;

  final DateTime startedAt;
  final DateTime endedAt;

  /// Planned focus only. Breaks are not included.
  final Duration plannedFocusDuration;

  final List<FocusBlock> plan;

  /// Real focus time only. Paused periods and breaks are excluded.
  final List<FocusInterval> focusIntervals;

  /// Explicit paused intervals. These are useful for later session analytics.
  final List<FocusInterval> pauseIntervals;

  /// Actual break intervals. A skipped break therefore records only the
  /// portion that was actually taken.
  final List<FocusInterval> breakIntervals;

  final int completedFocusBlocks;
  final bool completedNaturally;

  const FocusSession({
    required this.id,
    this.taskId,
    required this.taskName,
    this.taskOccurrenceDate,
    this.taskScheduledStart,
    this.taskScheduledEnd,
    required this.startedAt,
    required this.endedAt,
    required this.plannedFocusDuration,
    required this.plan,
    required this.focusIntervals,
    this.pauseIntervals = const [],
    this.breakIntervals = const [],
    required this.completedFocusBlocks,
    required this.completedNaturally,
  });

  Duration get actualFocusDuration {
    return focusIntervals.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }

  Duration get pausedDuration {
    return pauseIntervals.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }

  Duration get breakDuration {
    return breakIntervals.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }

  Duration get totalElapsedDuration {
    return endedAt.difference(startedAt);
  }

  int get totalFocusBlocks {
    return plan.where((block) => block.isFocus).length;
  }

  DateTime? get linkedOccurrenceDate {
    if (taskId == null) return null;
    final explicit = taskOccurrenceDate;
    if (explicit != null) {
      final local = explicit.isUtc ? explicit.toLocal() : explicit;
      return DateTime(local.year, local.month, local.day);
    }

    // Backward-compatible fallback for schema-v1 sessions that did not store
    // an explicit task occurrence. Historical v1 recurring sessions are
    // attributed to the local day on which that focus session started.
    final localStart = startedAt.isUtc ? startedAt.toLocal() : startedAt;
    return DateTime(localStart.year, localStart.month, localStart.day);
  }

  Duration? get taskPlannedDuration {
    final start = taskScheduledStart;
    final end = taskScheduledEnd;
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 2,
      'id': id,
      'taskId': taskId,
      'taskName': taskName,
      'taskOccurrenceDate': taskOccurrenceDate?.toIso8601String(),
      'taskScheduledStart': taskScheduledStart?.toIso8601String(),
      'taskScheduledEnd': taskScheduledEnd?.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'plannedFocusSeconds': plannedFocusDuration.inSeconds,
      'plan': plan
          .map(
            (block) => {
              'type': block.type.name,
              'durationSeconds': block.duration.inSeconds,
            },
          )
          .toList(growable: false),
      'focusIntervals': focusIntervals
          .map((interval) => interval.toMap())
          .toList(growable: false),
      'pauseIntervals': pauseIntervals
          .map((interval) => interval.toMap())
          .toList(growable: false),
      'breakIntervals': breakIntervals
          .map((interval) => interval.toMap())
          .toList(growable: false),
      'completedFocusBlocks': completedFocusBlocks,
      'completedNaturally': completedNaturally,
    };
  }

  factory FocusSession.fromMap(Map<dynamic, dynamic> map) {
    final schemaVersion = map['schemaVersion'];

    if (schemaVersion is! num ||
        (schemaVersion.toInt() != 1 && schemaVersion.toInt() != 2)) {
      throw const FormatException(
        'Unsupported focus session schema version.',
      );
    }
    final version = schemaVersion.toInt();

    final startedAt = _requiredDate(map, 'startedAt');
    final endedAt = _requiredDate(map, 'endedAt');

    if (endedAt.isBefore(startedAt)) {
      throw const FormatException(
        'Focus session end cannot be before start.',
      );
    }

    final plannedSeconds = _requiredPositiveInt(
      map,
      'plannedFocusSeconds',
    );

    final plan = _parsePlan(map['plan']);
    final completedBlocks = _requiredNonNegativeInt(
      map,
      'completedFocusBlocks',
    );

    final totalFocusBlocks =
        plan.where((block) => block.isFocus).length;

    if (completedBlocks > totalFocusBlocks) {
      throw const FormatException(
        'Completed focus blocks exceed the session plan.',
      );
    }

    final completedNaturally = map['completedNaturally'];
    if (completedNaturally is! bool) {
      throw const FormatException(
        'Missing or invalid completedNaturally.',
      );
    }

    final plannedFromBlocks = plan
        .where((block) => block.isFocus)
        .fold<int>(
          0,
          (total, block) => total + block.duration.inSeconds,
        );

    if (plannedFromBlocks != plannedSeconds) {
      throw const FormatException(
        'Planned focus duration does not match the focus blocks.',
      );
    }

    final focusIntervals = _parseIntervals(
      map['focusIntervals'],
    );
    final pauseIntervals = _parseIntervals(
      map['pauseIntervals'],
    );
    final breakIntervals = _parseIntervals(
      map['breakIntervals'],
    );

    _validateIntervalsInsideSession(
      focusIntervals,
      startedAt,
      endedAt,
    );
    _validateIntervalsInsideSession(
      pauseIntervals,
      startedAt,
      endedAt,
    );
    _validateIntervalsInsideSession(
      breakIntervals,
      startedAt,
      endedAt,
    );

    final taskOccurrenceDate = version >= 2
        ? _optionalDate(map['taskOccurrenceDate'])
        : null;
    final taskScheduledStart = version >= 2
        ? _optionalDate(map['taskScheduledStart'])
        : null;
    final taskScheduledEnd = version >= 2
        ? _optionalDate(map['taskScheduledEnd'])
        : null;

    if ((taskScheduledStart == null) != (taskScheduledEnd == null)) {
      throw const FormatException(
        'Task schedule snapshot start/end must exist together.',
      );
    }
    if (taskScheduledStart != null &&
        taskScheduledEnd != null &&
        !taskScheduledEnd.isAfter(taskScheduledStart)) {
      throw const FormatException(
        'Task schedule snapshot end must be after start.',
      );
    }

    return FocusSession(
      id: _requiredString(map, 'id'),
      taskId: _optionalString(map['taskId']),
      taskName: _requiredString(map, 'taskName'),
      taskOccurrenceDate: taskOccurrenceDate,
      taskScheduledStart: taskScheduledStart,
      taskScheduledEnd: taskScheduledEnd,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedFocusDuration: Duration(seconds: plannedSeconds),
      plan: List<FocusBlock>.unmodifiable(plan),
      focusIntervals: List<FocusInterval>.unmodifiable(
        focusIntervals,
      ),
      pauseIntervals: List<FocusInterval>.unmodifiable(
        pauseIntervals,
      ),
      breakIntervals: List<FocusInterval>.unmodifiable(
        breakIntervals,
      ),
      completedFocusBlocks: completedBlocks,
      completedNaturally: completedNaturally,
    );
  }

  static List<FocusBlock> _parsePlan(dynamic value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException(
        'Focus session plan is missing or invalid.',
      );
    }

    final blocks = <FocusBlock>[];

    for (final raw in value) {
      if (raw is! Map) {
        throw const FormatException(
          'Invalid focus block record.',
        );
      }

      final map = Map<dynamic, dynamic>.from(raw);
      final typeName = map['type'];

      if (typeName is! String) {
        throw const FormatException(
          'Focus block type is missing or invalid.',
        );
      }

      FocusBlockType? type;

      for (final candidate in FocusBlockType.values) {
        if (candidate.name == typeName) {
          type = candidate;
          break;
        }
      }

      if (type == null) {
        throw FormatException(
          'Unknown focus block type: $typeName',
        );
      }

      final durationSeconds = _requiredPositiveInt(
        map,
        'durationSeconds',
      );

      blocks.add(
        FocusBlock(
          type: type,
          duration: Duration(seconds: durationSeconds),
        ),
      );
    }

    return blocks;
  }

  static List<FocusInterval> _parseIntervals(dynamic value) {
    if (value is! List) {
      throw const FormatException(
        'Focus session intervals are missing or invalid.',
      );
    }

    final intervals = <FocusInterval>[];

    for (final raw in value) {
      if (raw is! Map) {
        throw const FormatException(
          'Invalid focus interval record.',
        );
      }

      intervals.add(
        FocusInterval.fromMap(
          Map<dynamic, dynamic>.from(raw),
        ),
      );
    }

    return intervals;
  }
}

void _validateIntervalsInsideSession(
  List<FocusInterval> intervals,
  DateTime startedAt,
  DateTime endedAt,
) {
  for (final interval in intervals) {
    if (interval.startTime.isBefore(startedAt) ||
        interval.endTime.isAfter(endedAt)) {
      throw const FormatException(
        'Focus session interval falls outside the session bounds.',
      );
    }
  }
}

String? _optionalString(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid optional string value.');
  }

  return value;
}

String _requiredString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }

  return value;
}

DateTime? _optionalDate(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid optional date value.');
  }
  return DateTime.tryParse(value) ??
      (throw const FormatException('Invalid optional date value.'));
}

DateTime _requiredDate(Map<dynamic, dynamic> map, String key) {
  final value = map[key];

  if (value is! String) {
    throw FormatException('Missing or invalid $key.');
  }

  return DateTime.tryParse(value) ??
      (throw FormatException('Invalid date value for $key.'));
}

int _requiredPositiveInt(
  Map<dynamic, dynamic> map,
  String key,
) {
  final value = map[key];

  if (value is! num || value.toInt() <= 0) {
    throw FormatException('Missing or invalid $key.');
  }

  return value.toInt();
}

int _requiredNonNegativeInt(
  Map<dynamic, dynamic> map,
  String key,
) {
  final value = map[key];

  if (value is! num || value.toInt() < 0) {
    throw FormatException('Missing or invalid $key.');
  }

  return value.toInt();
}

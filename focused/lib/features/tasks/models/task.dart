import 'task_recurrence.dart';

enum TaskPriority { critical, important, growth }

extension TaskPriorityInfo on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.critical:
        return 'Critical';
      case TaskPriority.important:
        return 'Important';
      case TaskPriority.growth:
        return 'Growth';
    }
  }

  int get sortOrder {
    switch (this) {
      case TaskPriority.critical:
        return 0;
      case TaskPriority.important:
        return 1;
      case TaskPriority.growth:
        return 2;
    }
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? plannedDate;
  final DateTime? deadline;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final TaskRecurrence recurrence;
  final Set<int> customWeekdays;
  final int? reminderMinutesBefore;
  final int? lateReminderMinutesAfter;
  final int guardWarningSeconds;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isSquadTask;
  final String? squadGroupId;
  final bool isReminder;

  Duration? get scheduledDuration {
    final start = scheduledStart;
    final end = scheduledEnd;
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  int? get scheduledDurationMinutes {
    final duration = scheduledDuration;
    if (duration == null) return null;
    final minutes = duration.inMinutes;
    return minutes > 0 ? minutes : 1;
  }

  int get defaultFocusMinutes => scheduledDurationMinutes ?? 60;

  bool get isCompletedLate {
    if (!isCompleted || completedAt == null) return false;
    if (deadline != null && completedAt!.isAfter(deadline!)) return true;
    if (scheduledEnd != null && completedAt!.isAfter(scheduledEnd!))
      return true;
    return false;
  }

  Task({
    required String id,
    required String title,
    this.description = '',
    required this.priority,
    this.plannedDate,
    this.deadline,
    this.scheduledStart,
    this.scheduledEnd,
    this.recurrence = TaskRecurrence.none,
    this.customWeekdays = const {},
    this.reminderMinutesBefore,
    this.lateReminderMinutesAfter,
    this.guardWarningSeconds = 30,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.isSquadTask = false,
    this.squadGroupId,
    this.isReminder = false,
  }) : id = id.trim(),
       title = title.trim() {
    if (this.id.isEmpty) throw ArgumentError('Task ID cannot be empty.');
    if (this.title.isEmpty) throw ArgumentError('Task title cannot be empty.');

    final hasStart = scheduledStart != null;
    final hasEnd = scheduledEnd != null;
    if (hasStart != hasEnd) {
      throw ArgumentError(
        'Scheduled start and end must either both exist or both be null.',
      );
    }

    if (scheduledStart != null &&
        scheduledEnd != null &&
        !scheduledEnd!.isAfter(scheduledStart!)) {
      throw ArgumentError('Scheduled end must be after scheduled start.');
    }

    if (!isCompleted && completedAt != null) {
      throw ArgumentError('An incomplete task cannot have completedAt.');
    }
    if (isCompleted && completedAt == null) {
      throw ArgumentError('A completed task must have completedAt.');
    }

    if (recurrence != TaskRecurrence.none &&
        (scheduledStart == null || scheduledEnd == null)) {
      throw ArgumentError('Recurring tasks must have a schedule.');
    }

    if (recurrence == TaskRecurrence.customDays && customWeekdays.isEmpty) {
      throw ArgumentError('Custom recurrence requires at least one weekday.');
    }

    for (final weekday in customWeekdays) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) {
        throw ArgumentError('Weekday must be between 1 and 7.');
      }
    }

    if (reminderMinutesBefore != null && reminderMinutesBefore! < 0) {
      throw ArgumentError('Reminder minutes cannot be negative.');
    }
    if (reminderMinutesBefore != null && scheduledStart == null) {
      throw ArgumentError('A reminder requires a scheduled task.');
    }
  }

  Task markCompleted(DateTime time) {
    if (isCompleted) return this;
    return Task(
      id: id,
      title: title,
      description: description,
      priority: priority,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recurrence: recurrence,
      customWeekdays: Set<int>.from(customWeekdays),
      reminderMinutesBefore: reminderMinutesBefore,
      lateReminderMinutesAfter: lateReminderMinutesAfter,
      guardWarningSeconds: guardWarningSeconds,
      isCompleted: true,
      createdAt: createdAt,
      completedAt: time,
      isSquadTask: isSquadTask,
      squadGroupId: squadGroupId,
      isReminder: isReminder,
    );
  }

  Task markIncomplete() {
    if (!isCompleted) return this;
    return Task(
      id: id,
      title: title,
      description: description,
      priority: priority,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recurrence: recurrence,
      customWeekdays: Set<int>.from(customWeekdays),
      reminderMinutesBefore: reminderMinutesBefore,
      lateReminderMinutesAfter: lateReminderMinutesAfter,
      guardWarningSeconds: guardWarningSeconds,
      isCompleted: false,
      createdAt: createdAt,
      completedAt: null,
      isSquadTask: isSquadTask,
      squadGroupId: squadGroupId,
      isReminder: isReminder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 3,
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.name,
      'plannedDate': plannedDate?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'scheduledStart': scheduledStart?.toIso8601String(),
      'scheduledEnd': scheduledEnd?.toIso8601String(),
      'recurrence': recurrence.name,
      'customWeekdays': customWeekdays.toList()..sort(),
      'reminderMinutesBefore': reminderMinutesBefore,
      'lateReminderMinutesAfter': lateReminderMinutesAfter,
      'guardWarningSeconds': guardWarningSeconds,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isSquadTask': isSquadTask,
      'squadGroupId': squadGroupId,
      'isReminder': isReminder,
    };
  }

  factory Task.fromMap(Map<dynamic, dynamic> map) {
    final priorityName = map['priority'];
    if (priorityName is! String) {
      throw const FormatException('Task priority is missing or invalid.');
    }
    final matches = TaskPriority.values.where((p) => p.name == priorityName);
    if (matches.isEmpty) {
      throw FormatException('Unknown task priority: $priorityName');
    }

    return Task(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: map['description'] is String
          ? map['description'] as String
          : '',
      priority: matches.first,
      plannedDate: _optionalDate(map['plannedDate']),
      deadline: _optionalDate(map['deadline']),
      scheduledStart: _optionalDate(map['scheduledStart']),
      scheduledEnd: _optionalDate(map['scheduledEnd']),
      recurrence: _parseRecurrence(map['recurrence']),
      customWeekdays: _parseWeekdays(map['customWeekdays']),
      reminderMinutesBefore: map['reminderMinutesBefore'] is num
          ? (map['reminderMinutesBefore'] as num).toInt()
          : null,
      lateReminderMinutesAfter: map['lateReminderMinutesAfter'] is num
          ? (map['lateReminderMinutesAfter'] as num).toInt()
          : null,
      guardWarningSeconds: map['guardWarningSeconds'] is num
          ? (map['guardWarningSeconds'] as num).toInt()
          : 30,
      isCompleted: map['isCompleted'] is bool
          ? map['isCompleted'] as bool
          : false,
      createdAt: _requiredDate(map, 'createdAt'),
      completedAt: _optionalDate(map['completedAt']),
      isSquadTask: map['isSquadTask'] is bool
          ? map['isSquadTask'] as bool
          : false,
      squadGroupId: map['squadGroupId'] as String?,
      isReminder: map['isReminder'] is bool ? map['isReminder'] as bool : false,
    );
  }

  static TaskRecurrence _parseRecurrence(dynamic value) {
    if (value is String) {
      for (final recurrence in TaskRecurrence.values) {
        if (recurrence.name == value) return recurrence;
      }
    }
    return TaskRecurrence.none;
  }

  static Set<int> _parseWeekdays(dynamic value) {
    if (value is! List) return <int>{};
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet();
  }
}

String _requiredString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

DateTime _requiredDate(Map<dynamic, dynamic> map, String key) {
  final value = _optionalDate(map[key]);
  if (value == null) throw FormatException('Missing or invalid $key.');
  return value;
}

DateTime? _optionalDate(dynamic value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid date value.');
  return DateTime.tryParse(value) ??
      (throw FormatException('Invalid date: $value'));
}

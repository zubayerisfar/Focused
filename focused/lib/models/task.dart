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

  final int estimatedMinutes;

  /// Day the user intends to work on this task.
  ///
  /// This is NOT the same thing as a deadline.
  final DateTime? plannedDate;

  /// Latest time/date by which the task should be finished.
  final DateTime? deadline;

  /// Optional calendar time.
  ///
  /// These will later connect to Google Calendar.
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  final bool isCompleted;

  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    required String id,
    required String title,
    this.description = '',
    required this.priority,
    required this.estimatedMinutes,
    this.plannedDate,
    this.deadline,
    this.scheduledStart,
    this.scheduledEnd,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  }) : id = id.trim(),
       title = title.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError('Task ID cannot be empty.');
    }

    if (this.title.isEmpty) {
      throw ArgumentError('Task title cannot be empty.');
    }

    if (estimatedMinutes <= 0) {
      throw ArgumentError('Estimated duration must be greater than zero.');
    }

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
  }

  Task markCompleted(DateTime time) {
    if (isCompleted) {
      return this;
    }

    return Task(
      id: id,
      title: title,
      description: description,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      isCompleted: true,
      createdAt: createdAt,
      completedAt: time,
    );
  }

  Task markIncomplete() {
    if (!isCompleted) {
      return this;
    }

    return Task(
      id: id,
      title: title,
      description: description,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      plannedDate: plannedDate,
      deadline: deadline,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      isCompleted: false,
      createdAt: createdAt,
      completedAt: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.name,
      'estimatedMinutes': estimatedMinutes,
      'plannedDate': plannedDate?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'scheduledStart': scheduledStart?.toIso8601String(),
      'scheduledEnd': scheduledEnd?.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<dynamic, dynamic> map) {
    final priorityName = map['priority'];

    if (priorityName is! String) {
      throw const FormatException('Task priority is missing or invalid.');
    }

    final priority = TaskPriority.values.where(
      (item) => item.name == priorityName,
    );

    if (priority.isEmpty) {
      throw FormatException('Unknown task priority: $priorityName');
    }

    return Task(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      description: map['description'] as String? ?? '',
      priority: priority.first,
      estimatedMinutes: _requiredInt(map, 'estimatedMinutes'),
      plannedDate: _optionalDate(map['plannedDate']),
      deadline: _optionalDate(map['deadline']),
      scheduledStart: _optionalDate(map['scheduledStart']),
      scheduledEnd: _optionalDate(map['scheduledEnd']),
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: _requiredDate(map, 'createdAt'),
      completedAt: _optionalDate(map['completedAt']),
    );
  }
}

String _requiredString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }

  return value;
}

int _requiredInt(Map<dynamic, dynamic> map, String key) {
  final value = map[key];

  if (value is! int) {
    throw FormatException('Missing or invalid $key.');
  }

  return value;
}

DateTime _requiredDate(Map<dynamic, dynamic> map, String key) {
  final value = map[key];

  if (value is! String) {
    throw FormatException('Missing or invalid $key.');
  }

  final date = DateTime.tryParse(value);

  if (date == null) {
    throw FormatException('Invalid date stored for $key.');
  }

  return date;
}

DateTime? _optionalDate(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Stored date is invalid.');
  }

  final date = DateTime.tryParse(value);

  if (date == null) {
    throw FormatException('Invalid stored date: $value');
  }

  return date;
}

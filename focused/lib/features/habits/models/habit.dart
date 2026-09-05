import 'package:flutter/material.dart';

import 'habit_definition_revision.dart';

enum HabitGoalType { checkIn, count, duration }

class Habit {
  static const Object _unset = Object();

  final String id;
  final String title;
  final HabitGoalType goalType;
  final int targetValue;
  final String unit;
  final Set<int> weekdays;
  final int iconCodePoint;
  final int colorValue;
  final int? reminderMinutesFromMidnight;
  final int? lateReminderMinutesAfter;
  final DateTime createdAt;

  /// The local calendar day from which the current goal/repeat definition
  /// applies. Older definitions are preserved in [definitionHistory].
  final DateTime definitionEffectiveFromDay;
  final List<HabitDefinitionRevision> definitionHistory;

  Habit({
    required this.id,
    required this.title,
    required this.goalType,
    required this.targetValue,
    required this.unit,
    required Set<int> weekdays,
    required this.iconCodePoint,
    required this.colorValue,
    this.reminderMinutesFromMidnight,
    this.lateReminderMinutesAfter,
    required DateTime createdAt,
    DateTime? definitionEffectiveFromDay,
    List<HabitDefinitionRevision> definitionHistory = const [],
  }) : weekdays = Set<int>.unmodifiable(weekdays),
       createdAt = createdAt,
       definitionEffectiveFromDay = _dateOnly(
         definitionEffectiveFromDay ?? createdAt,
       ),
       definitionHistory = List<HabitDefinitionRevision>.unmodifiable(
         definitionHistory,
       ) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Habit id cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Habit title cannot be empty.');
    }
    if (targetValue < 1) {
      throw ArgumentError('Habit target must be at least 1.');
    }
    if (this.weekdays.isEmpty) {
      throw ArgumentError('Habit must repeat on at least one weekday.');
    }
    if (this.weekdays.any(
      (day) => day < DateTime.monday || day > DateTime.sunday,
    )) {
      throw ArgumentError('Habit weekdays must be between 1 and 7.');
    }

    final reminder = reminderMinutesFromMidnight;
    if (reminder != null && (reminder < 0 || reminder >= 24 * 60)) {
      throw ArgumentError('Habit reminder time must be within a single day.');
    }

    final createdDay = _dateOnly(createdAt);
    if (this.definitionEffectiveFromDay.isBefore(createdDay)) {
      throw ArgumentError(
        'Habit definition cannot become effective before the habit was created.',
      );
    }
  }

  /// Current repeat definition. Use [occursOnDate] for historical analytics.
  bool occursOn(DateTime date) => weekdays.contains(date.weekday);

  /// Returns whether this habit was scheduled on [date], respecting definition
  /// changes that were made later.
  bool occursOnDate(DateTime date) {
    final day = _dateOnly(date);
    if (day.isBefore(_dateOnly(createdAt))) return false;

    for (final revision in definitionHistory) {
      if (revision.appliesTo(day)) {
        return revision.occursOn(day);
      }
    }

    if (day.isBefore(definitionEffectiveFromDay)) return false;
    return weekdays.contains(day.weekday);
  }

  /// Returns the completion target that applied on [date]. Null means the
  /// habit did not yet have a valid definition on that date.
  int? targetValueForDate(DateTime date) {
    final day = _dateOnly(date);
    if (day.isBefore(_dateOnly(createdAt))) return null;

    for (final revision in definitionHistory) {
      if (revision.appliesTo(day)) {
        return revision.targetValue;
      }
    }

    if (day.isBefore(definitionEffectiveFromDay)) return null;
    return targetValue;
  }

  IconData get icon {
    // Return only compile-time Material icon constants so release builds
    // can tree-shake the MaterialIcons font safely.
    if (iconCodePoint == Icons.menu_book_rounded.codePoint) {
      return Icons.menu_book_rounded;
    }
    if (iconCodePoint == Icons.fitness_center_rounded.codePoint) {
      return Icons.fitness_center_rounded;
    }
    if (iconCodePoint == Icons.water_drop_rounded.codePoint) {
      return Icons.water_drop_rounded;
    }
    if (iconCodePoint == Icons.self_improvement_rounded.codePoint) {
      return Icons.self_improvement_rounded;
    }
    if (iconCodePoint == Icons.bedtime_outlined.codePoint) {
      return Icons.bedtime_outlined;
    }

    // Default + backward-compatible fallback.
    return Icons.check_rounded;
  }

  Color get color => Color(colorValue);

  bool get hasReminder => reminderMinutesFromMidnight != null;

  TimeOfDay? get reminderTime {
    final minutes = reminderMinutesFromMidnight;
    if (minutes == null) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Habit copyWith({
    String? id,
    String? title,
    HabitGoalType? goalType,
    int? targetValue,
    String? unit,
    Set<int>? weekdays,
    int? iconCodePoint,
    int? colorValue,
    Object? reminderMinutesFromMidnight = _unset,
    Object? lateReminderMinutesAfter = _unset,
    DateTime? createdAt,
    DateTime? definitionEffectiveFromDay,
    List<HabitDefinitionRevision>? definitionHistory,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      goalType: goalType ?? this.goalType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      weekdays: weekdays ?? this.weekdays,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      reminderMinutesFromMidnight:
          identical(reminderMinutesFromMidnight, _unset)
          ? this.reminderMinutesFromMidnight
          : reminderMinutesFromMidnight as int?,
      lateReminderMinutesAfter: identical(lateReminderMinutesAfter, _unset)
          ? this.lateReminderMinutesAfter
          : lateReminderMinutesAfter as int?,
      createdAt: createdAt ?? this.createdAt,
      definitionEffectiveFromDay:
          definitionEffectiveFromDay ?? this.definitionEffectiveFromDay,
      definitionHistory: definitionHistory ?? this.definitionHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 3,
      'id': id,
      'title': title,
      'goalType': goalType.name,
      'targetValue': targetValue,
      'unit': unit,
      'weekdays': weekdays.toList()..sort(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'reminderMinutesFromMidnight': reminderMinutesFromMidnight,
      'lateReminderMinutesAfter': lateReminderMinutesAfter,
      'createdAt': createdAt.toIso8601String(),
      'definitionEffectiveFromDay': definitionEffectiveFromDay
          .toIso8601String(),
      'definitionHistory': definitionHistory
          .map((item) => item.toMap())
          .toList(),
    };
  }

  factory Habit.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    final goalTypeRaw = map['goalType'];
    final targetValue = map['targetValue'];
    final unit = map['unit'];
    final weekdaysRaw = map['weekdays'];
    final iconCodePoint = map['iconCodePoint'];
    final colorValue = map['colorValue'];
    final reminderRaw = map['reminderMinutesFromMidnight'];
    final lateReminderRaw = map['lateReminderMinutesAfter'];
    final createdAtRaw = map['createdAt'];
    final definitionEffectiveRaw = map['definitionEffectiveFromDay'];
    final definitionHistoryRaw = map['definitionHistory'];

    if (id is! String || title is! String || goalTypeRaw is! String) {
      throw const FormatException('Invalid habit identity.');
    }
    if (targetValue is! int || unit is! String) {
      throw const FormatException('Invalid habit goal.');
    }
    if (weekdaysRaw is! List || iconCodePoint is! int || colorValue is! int) {
      throw const FormatException('Invalid habit presentation.');
    }
    if (createdAtRaw is! String) {
      throw const FormatException('Invalid habit creation time.');
    }
    if (reminderRaw != null && reminderRaw is! int) {
      throw const FormatException('Invalid habit reminder time.');
    }
    if (lateReminderRaw != null && lateReminderRaw is! int) {
      throw const FormatException('Invalid habit late reminder time.');
    }
    if (definitionEffectiveRaw != null && definitionEffectiveRaw is! String) {
      throw const FormatException('Invalid habit definition start.');
    }
    if (definitionHistoryRaw != null && definitionHistoryRaw is! List) {
      throw const FormatException('Invalid habit definition history.');
    }

    final goalType = HabitGoalType.values
        .where((value) => value.name == goalTypeRaw)
        .firstOrNull;
    final createdAt = DateTime.tryParse(createdAtRaw);
    final weekdays = weekdaysRaw.whereType<int>().toSet();
    final definitionEffectiveFromDay = definitionEffectiveRaw is String
        ? DateTime.tryParse(definitionEffectiveRaw)
        : createdAt;

    final history = <HabitDefinitionRevision>[];
    if (definitionHistoryRaw is List) {
      for (final raw in definitionHistoryRaw) {
        if (raw is! Map) {
          throw const FormatException('Invalid habit definition history item.');
        }
        history.add(
          HabitDefinitionRevision.fromMap(Map<dynamic, dynamic>.from(raw)),
        );
      }
    }

    if (goalType == null ||
        createdAt == null ||
        definitionEffectiveFromDay == null ||
        weekdays.length != weekdaysRaw.length) {
      throw const FormatException('Invalid habit data.');
    }

    return Habit(
      id: id,
      title: title,
      goalType: goalType,
      targetValue: targetValue,
      unit: unit,
      weekdays: weekdays,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      reminderMinutesFromMidnight: reminderRaw as int?,
      lateReminderMinutesAfter: lateReminderRaw as int?,
      createdAt: createdAt,
      definitionEffectiveFromDay: definitionEffectiveFromDay,
      definitionHistory: history,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

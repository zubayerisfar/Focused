import 'package:flutter/material.dart';

enum HabitGoalType {
  checkIn,
  count,
  duration,
}

class Habit {
  final String id;
  final String title;
  final HabitGoalType goalType;
  final int targetValue;
  final String unit;
  final Set<int> weekdays;
  final int iconCodePoint;
  final int colorValue;
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.title,
    required this.goalType,
    required this.targetValue,
    required this.unit,
    required Set<int> weekdays,
    required this.iconCodePoint,
    required this.colorValue,
    required this.createdAt,
  }) : weekdays = Set<int>.unmodifiable(weekdays) {
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
    if (this.weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      throw ArgumentError('Habit weekdays must be between 1 and 7.');
    }
  }

  bool occursOn(DateTime date) => weekdays.contains(date.weekday);

  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: 'MaterialIcons',
      );

  Color get color => Color(colorValue);

  Habit copyWith({
    String? id,
    String? title,
    HabitGoalType? goalType,
    int? targetValue,
    String? unit,
    Set<int>? weekdays,
    int? iconCodePoint,
    int? colorValue,
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'id': id,
      'title': title,
      'goalType': goalType.name,
      'targetValue': targetValue,
      'unit': unit,
      'weekdays': weekdays.toList()..sort(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
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
    final createdAtRaw = map['createdAt'];

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

    final goalType = HabitGoalType.values.where((value) => value.name == goalTypeRaw).firstOrNull;
    final createdAt = DateTime.tryParse(createdAtRaw);
    final weekdays = weekdaysRaw.whereType<int>().toSet();

    if (goalType == null || createdAt == null || weekdays.length != weekdaysRaw.length) {
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
      createdAt: createdAt,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

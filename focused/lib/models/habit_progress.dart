class HabitProgress {
  final String habitId;
  final DateTime date;
  final int value;
  final DateTime updatedAt;

  HabitProgress({
    required this.habitId,
    required DateTime date,
    required this.value,
    required this.updatedAt,
  }) : date = DateTime(date.year, date.month, date.day) {
    if (habitId.trim().isEmpty) {
      throw ArgumentError('Habit id cannot be empty.');
    }
    if (value < 0) {
      throw ArgumentError('Habit progress cannot be negative.');
    }
  }

  String get storageKey => storageKeyFor(habitId, date);

  static String storageKeyFor(String habitId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return '${habitId}_${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'habitId': habitId,
      'date': date.toIso8601String(),
      'value': value,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HabitProgress.fromMap(Map<dynamic, dynamic> map) {
    final habitId = map['habitId'];
    final dateRaw = map['date'];
    final value = map['value'];
    final updatedAtRaw = map['updatedAt'];

    if (habitId is! String || dateRaw is! String || value is! int || updatedAtRaw is! String) {
      throw const FormatException('Invalid habit progress record.');
    }

    final date = DateTime.tryParse(dateRaw);
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (date == null || updatedAt == null) {
      throw const FormatException('Invalid habit progress timestamps.');
    }

    return HabitProgress(
      habitId: habitId,
      date: date,
      value: value,
      updatedAt: updatedAt,
    );
  }
}

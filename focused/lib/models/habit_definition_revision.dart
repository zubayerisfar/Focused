class HabitDefinitionRevision {
  final DateTime effectiveFromDay;
  final DateTime effectiveUntilDayExclusive;
  final int targetValue;
  final Set<int> weekdays;

  HabitDefinitionRevision({
    required DateTime effectiveFromDay,
    required DateTime effectiveUntilDayExclusive,
    required this.targetValue,
    required Set<int> weekdays,
  })  : effectiveFromDay = _dateOnly(effectiveFromDay),
        effectiveUntilDayExclusive = _dateOnly(effectiveUntilDayExclusive),
        weekdays = Set<int>.unmodifiable(weekdays) {
    if (!this.effectiveFromDay.isBefore(this.effectiveUntilDayExclusive)) {
      throw ArgumentError('Habit definition revision must cover at least one day.');
    }
    if (targetValue < 1) {
      throw ArgumentError('Habit revision target must be positive.');
    }
    if (this.weekdays.isEmpty ||
        this.weekdays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      throw ArgumentError('Habit revision weekdays must be between 1 and 7.');
    }
  }

  bool appliesTo(DateTime date) {
    final day = _dateOnly(date);
    return !day.isBefore(effectiveFromDay) &&
        day.isBefore(effectiveUntilDayExclusive);
  }

  bool occursOn(DateTime date) => weekdays.contains(date.weekday);

  Map<String, dynamic> toMap() {
    return {
      'effectiveFromDay': effectiveFromDay.toIso8601String(),
      'effectiveUntilDayExclusive': effectiveUntilDayExclusive.toIso8601String(),
      'targetValue': targetValue,
      'weekdays': weekdays.toList()..sort(),
    };
  }

  factory HabitDefinitionRevision.fromMap(Map<dynamic, dynamic> map) {
    final fromRaw = map['effectiveFromDay'];
    final untilRaw = map['effectiveUntilDayExclusive'];
    final targetRaw = map['targetValue'];
    final weekdaysRaw = map['weekdays'];

    if (fromRaw is! String ||
        untilRaw is! String ||
        targetRaw is! int ||
        weekdaysRaw is! List) {
      throw const FormatException('Invalid habit definition revision.');
    }

    final from = DateTime.tryParse(fromRaw);
    final until = DateTime.tryParse(untilRaw);
    final weekdays = weekdaysRaw.whereType<int>().toSet();

    if (from == null ||
        until == null ||
        weekdays.length != weekdaysRaw.length) {
      throw const FormatException('Invalid habit definition revision data.');
    }

    return HabitDefinitionRevision(
      effectiveFromDay: from,
      effectiveUntilDayExclusive: until,
      targetValue: targetRaw,
      weekdays: weekdays,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }
}

enum TaskRecurrence {
  none,
  daily,
  weekdays,
  weekly,
  customDays,
}

extension TaskRecurrenceInfo on TaskRecurrence {
  String get label {
    switch (this) {
      case TaskRecurrence.none:
        return 'Does not repeat';
      case TaskRecurrence.daily:
        return 'Daily';
      case TaskRecurrence.weekdays:
        return 'Weekdays';
      case TaskRecurrence.weekly:
        return 'Weekly';
      case TaskRecurrence.customDays:
        return 'Custom days';
    }
  }
}

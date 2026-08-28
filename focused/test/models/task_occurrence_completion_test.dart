import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/task_occurrence_completion.dart';

void main() {
  test('normalizes occurrence identity to the local calendar date', () {
    final completion = TaskOccurrenceCompletion(
      taskId: 'daily-task',
      occurrenceDate: DateTime(2026, 8, 27, 19, 30),
      completedAt: DateTime(2026, 8, 27, 20),
    );

    expect(
      completion.occurrenceDate,
      DateTime(2026, 8, 27),
    );
    expect(
      completion.storageKey,
      'daily-task|2026-08-27',
    );
  });

  test('round-trips through map serialization', () {
    final original = TaskOccurrenceCompletion(
      taskId: 'weekly-task',
      occurrenceDate: DateTime(2026, 8, 31),
      completedAt: DateTime(2026, 8, 31, 9, 45),
    );

    final restored = TaskOccurrenceCompletion.fromMap(
      original.toMap(),
    );

    expect(restored.taskId, original.taskId);
    expect(
      restored.occurrenceDate,
      original.occurrenceDate,
    );
    expect(restored.completedAt, original.completedAt);
  });

  test('rejects an empty task id', () {
    expect(
      () => TaskOccurrenceCompletion(
        taskId: '   ',
        occurrenceDate: DateTime(2026, 8, 27),
        completedAt: DateTime(2026, 8, 27, 20),
      ),
      throwsArgumentError,
    );
  });
}

import '../../focus/models/focus_analysis_result.dart';
import '../../focus/models/focus_session.dart';
import '../models/task_execution_period_summary.dart';
import '../models/task_execution_summary.dart';
import '../models/task_occurrence.dart';

class TaskExecutionAnalyzer {
  const TaskExecutionAnalyzer();

  TaskExecutionSummary summarizeOccurrence({
    required TaskOccurrence occurrence,
    required List<FocusSession> sessions,
    required Map<String, FocusAnalysisResult> analysesBySessionId,
    String? activeTaskId,
    DateTime? activeOccurrenceDate,
    DateTime? activeSessionStartedAt,
    DateTime? activeTaskScheduledStart,
    DateTime? activeTaskScheduledEnd,
    List<FocusInterval> activeFocusIntervals = const [],
  }) {
    final task = occurrence.task;
    final occurrenceDate = _dateOnly(occurrence.start);

    final linkedSessions = sessions.where((session) {
      if (session.taskId != task.id) return false;
      final linkedDay = session.linkedOccurrenceDate;
      return linkedDay != null && _sameDate(linkedDay, occurrenceDate);
    }).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final activeMatches = activeTaskId == task.id &&
        activeOccurrenceDate != null &&
        _sameDate(activeOccurrenceDate, occurrenceDate);

    DateTime plannedStart = occurrence.start;
    DateTime plannedEnd = occurrence.end;

    // Once execution starts, prefer the schedule snapshot captured at that
    // moment. A later task edit must not rewrite historical adherence math.
    for (final session in linkedSessions) {
      final start = session.taskScheduledStart;
      final end = session.taskScheduledEnd;
      if (start != null && end != null && end.isAfter(start)) {
        plannedStart = start;
        plannedEnd = end;
        break;
      }
    }
    if (linkedSessions.isEmpty &&
        activeMatches &&
        activeTaskScheduledStart != null &&
        activeTaskScheduledEnd != null &&
        activeTaskScheduledEnd.isAfter(activeTaskScheduledStart)) {
      plannedStart = activeTaskScheduledStart;
      plannedEnd = activeTaskScheduledEnd;
    }

    final intervals = <FocusInterval>[
      for (final session in linkedSessions) ...session.focusIntervals,
      if (activeMatches) ...activeFocusIntervals,
    ];

    final unionedFocus = _unionIntervals(intervals);
    final actualStart = unionedFocus.isEmpty
        ? (activeMatches ? activeSessionStartedAt : null)
        : unionedFocus.first.startTime;
    final actualEnd = unionedFocus.isEmpty
        ? null
        : unionedFocus.last.endTime;
    final activeDuration = _sumIntervals(unionedFocus);

    final analyzedSessions = <FocusSession>[];
    final missingAnalysisSessions = <FocusSession>[];

    for (final session in linkedSessions) {
      if (session.actualFocusDuration.inMicroseconds <= 0) continue;
      if (analysesBySessionId.containsKey(session.id)) {
        analyzedSessions.add(session);
      } else {
        missingAnalysisSessions.add(session);
      }
    }

    // An active session cannot have a final UsageStats interruption analysis
    // yet, so effective-focus metrics stay unknown until it ends.
    final analysisComplete = !activeMatches && missingAnalysisSessions.isEmpty;

    Duration? distracted;
    Duration? effective;
    int? interruptionCount;
    String? topInterrupter;

    if (analysisComplete) {
      final interruptionIntervals = <FocusInterval>[];
      final byApp = <String, Duration>{};
      var interruptions = 0;

      for (final session in analyzedSessions) {
        final analysis = analysesBySessionId[session.id]!;
        interruptions += analysis.interruptionCount;

        for (final interruption in analysis.interruptions) {
          interruptionIntervals.add(
            FocusInterval(
              startTime: interruption.startTime,
              endTime: interruption.endTime,
            ),
          );
        }

        for (final entry in analysis.distractionByApp.entries) {
          byApp.update(
            entry.key,
            (existing) => existing + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }

      distracted = _sumIntervals(_unionIntervals(interruptionIntervals));
      final effectiveMicroseconds =
          activeDuration.inMicroseconds - distracted.inMicroseconds;
      effective = Duration(
        microseconds: effectiveMicroseconds < 0 ? 0 : effectiveMicroseconds,
      );
      interruptionCount = interruptions;

      if (byApp.isNotEmpty) {
        final ranked = byApp.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topInterrupter = ranked.first.key;
      }
    }

    return TaskExecutionSummary(
      task: task,
      occurrenceDate: occurrenceDate,
      plannedStart: plannedStart,
      plannedEnd: plannedEnd,
      actualStart: actualStart,
      actualEnd: actualEnd,
      activeFocusDuration: activeDuration,
      distractedDuration: distracted,
      effectiveFocusDuration: effective,
      sessionCount: linkedSessions.length + (activeMatches ? 1 : 0),
      interruptionCount: interruptionCount,
      topInterrupterApp: topInterrupter,
      isCompleted: occurrence.isCompleted,
      completedAt: occurrence.completedAt,
      isActive: activeMatches,
      focusAnalysisComplete: analysisComplete,
    );
  }

  TaskExecutionPeriodSummary summarizePeriod({
    required DateTime startDay,
    required DateTime endDay,
    required List<TaskOccurrence> occurrences,
    required List<FocusSession> sessions,
    required Map<String, FocusAnalysisResult> analysesBySessionId,
    String? activeTaskId,
    DateTime? activeOccurrenceDate,
    DateTime? activeSessionStartedAt,
    DateTime? activeTaskScheduledStart,
    DateTime? activeTaskScheduledEnd,
    List<FocusInterval> activeFocusIntervals = const [],
    DateTime? asOf,
  }) {
    final summaries = occurrences.map((occurrence) {
      return summarizeOccurrence(
        occurrence: occurrence,
        sessions: sessions,
        analysesBySessionId: analysesBySessionId,
        activeTaskId: activeTaskId,
        activeOccurrenceDate: activeOccurrenceDate,
        activeSessionStartedAt: activeSessionStartedAt,
        activeTaskScheduledStart: activeTaskScheduledStart,
        activeTaskScheduledEnd: activeTaskScheduledEnd,
        activeFocusIntervals: activeFocusIntervals,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));

    return TaskExecutionPeriodSummary(
      startDay: _dateOnly(startDay),
      endDay: _dateOnly(endDay),
      tasks: List.unmodifiable(summaries),
      asOf: asOf,
    );
  }

  List<FocusInterval> _unionIntervals(List<FocusInterval> intervals) {
    final valid = intervals
        .where((interval) => interval.endTime.isAfter(interval.startTime))
        .toList(growable: false);

    if (valid.isEmpty) return const [];

    final sorted = [...valid]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final merged = <FocusInterval>[];
    var start = sorted.first.startTime;
    var end = sorted.first.endTime;

    for (var i = 1; i < sorted.length; i++) {
      final interval = sorted[i];
      if (!interval.startTime.isAfter(end)) {
        if (interval.endTime.isAfter(end)) {
          end = interval.endTime;
        }
        continue;
      }

      merged.add(FocusInterval(startTime: start, endTime: end));
      start = interval.startTime;
      end = interval.endTime;
    }

    merged.add(FocusInterval(startTime: start, endTime: end));
    return List.unmodifiable(merged);
  }

  Duration _sumIntervals(List<FocusInterval> intervals) {
    return intervals.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }
}

DateTime _dateOnly(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}

bool _sameDate(DateTime first, DateTime second) {
  final a = _dateOnly(first);
  final b = _dateOnly(second);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

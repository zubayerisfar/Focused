import 'dart:async';

import 'package:flutter/material.dart';

import '../models/focus_block.dart';
import '../models/focus_session.dart';
import '../services/focus_session_storage_service.dart';

class FocusProvider extends ChangeNotifier {
  final FocusSessionStorageService? _storageService;
  final DateTime Function() _now;

  FocusProvider({
    FocusSessionStorageService? storageService,
    DateTime Function()? now,
  })  : _storageService = storageService,
        _now = now ?? DateTime.now;

  Timer? _ticker;

  List<FocusBlock> _plan = [];
  int _currentBlockIndex = 0;

  int _remainingSeconds = 0;
  int _currentBlockTotalSeconds = 0;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _sessionFinished = false;

  String? _taskId;
  String _taskName = '';
  DateTime? _taskOccurrenceDate;
  DateTime? _taskScheduledStart;
  DateTime? _taskScheduledEnd;

  DateTime? _sessionStartedAt;
  DateTime? _blockDeadline;

  DateTime? _currentFocusIntervalStart;
  DateTime? _currentPauseIntervalStart;
  DateTime? _currentBreakIntervalStart;

  Duration _plannedFocusDuration = Duration.zero;

  final List<FocusInterval> _focusIntervals = [];
  final List<FocusInterval> _pauseIntervals = [];
  final List<FocusInterval> _breakIntervals = [];

  int _completedFocusBlocks = 0;

  FocusSession? _lastSession;

  final List<FocusSession> _sessionHistory = [];

  Future<void> _pendingPersistence = Future<void>.value();
  String? _lastPersistenceError;
  String? _lastPersistenceErrorSessionId;

  // ---------------------------------------------------------
  // STORED HISTORY
  // ---------------------------------------------------------

  Future<void> loadStoredSessions() async {
    final storage = _storageService;

    if (storage == null) {
      return;
    }

    _sessionHistory
      ..clear()
      ..addAll(storage.loadSessions());

    _sortSessionHistory();

    notifyListeners();
  }

  List<FocusSession> get sessionHistory {
    return List<FocusSession>.unmodifiable(_sessionHistory);
  }

  FocusSession? get latestSession {
    if (_sessionHistory.isEmpty) {
      return null;
    }

    return _sessionHistory.first;
  }

  String? get lastPersistenceError {
    final session = _lastSession;

    if (session == null ||
        _lastPersistenceErrorSessionId != session.id) {
      return null;
    }

    return _lastPersistenceError;
  }

  /// Useful for tests and for any future app-lifecycle flush.
  Future<void> flushPendingPersistence() {
    return _pendingPersistence;
  }

  List<FocusSession> sessionsForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);

    final result = _sessionHistory.where((session) {
      return session.focusIntervals.any((interval) {
        return interval.endTime.isAfter(dayStart) &&
            interval.startTime.isBefore(dayEnd);
      });
    }).toList();

    result.sort(
      (a, b) => b.endedAt.compareTo(a.endedAt),
    );

    return List<FocusSession>.unmodifiable(result);
  }

  int sessionCountForDate(DateTime date) {
    return sessionsForDate(date).length;
  }

  /// Local calendar dates containing any positive active-focus interval.
  Set<DateTime> focusActivityDates() {
    final result = <DateTime>{};

    for (final session in _sessionHistory) {
      for (final interval in session.focusIntervals) {
        if (!interval.endTime.isAfter(interval.startTime)) {
          continue;
        }

        var cursor = _dateOnlyLocal(interval.startTime);
        final lastDay = _dateOnlyLocal(
          interval.endTime.subtract(const Duration(microseconds: 1)),
        );

        while (!cursor.isAfter(lastDay)) {
          result.add(cursor);
          cursor = DateTime(
            cursor.year,
            cursor.month,
            cursor.day + 1,
          );
        }
      }
    }

    return Set<DateTime>.unmodifiable(result);
  }

  /// Longest single stored session's active-focus time inside [date].
  Duration longestFocusSessionForDate(DateTime date) {
    var longest = Duration.zero;

    for (final session in sessionsForDate(date)) {
      final duration = _focusDurationForSessionOnDate(
        session,
        date,
      );

      if (duration.compareTo(longest) > 0) {
        longest = duration;
      }
    }

    return longest;
  }

  /// Returns real active focus inside the selected local calendar day.
  ///
  /// Intervals are clipped to day boundaries and unioned before summing.
  /// That makes the metric safe even if malformed/duplicate history ever
  /// contains overlapping focus intervals.
  Duration focusedDurationForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);

    final clipped = <FocusInterval>[];

    for (final session in _sessionHistory) {
      for (final interval in session.focusIntervals) {
        if (!interval.endTime.isAfter(dayStart) ||
            !interval.startTime.isBefore(dayEnd)) {
          continue;
        }

        final start = interval.startTime.isBefore(dayStart)
            ? dayStart
            : interval.startTime;

        final end = interval.endTime.isAfter(dayEnd)
            ? dayEnd
            : interval.endTime;

        if (end.isAfter(start)) {
          clipped.add(
            FocusInterval(
              startTime: start,
              endTime: end,
            ),
          );
        }
      }
    }

    if (clipped.isEmpty) {
      return Duration.zero;
    }

    clipped.sort(
      (a, b) => a.startTime.compareTo(b.startTime),
    );

    var currentStart = clipped.first.startTime;
    var currentEnd = clipped.first.endTime;
    var total = Duration.zero;

    for (var index = 1; index < clipped.length; index++) {
      final interval = clipped[index];

      if (!interval.startTime.isAfter(currentEnd)) {
        if (interval.endTime.isAfter(currentEnd)) {
          currentEnd = interval.endTime;
        }

        continue;
      }

      total += currentEnd.difference(currentStart);
      currentStart = interval.startTime;
      currentEnd = interval.endTime;
    }

    total += currentEnd.difference(currentStart);

    return total;
  }

  Duration _focusDurationForSessionOnDate(
    FocusSession session,
    DateTime date,
  ) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);
    final clipped = <FocusInterval>[];

    for (final interval in session.focusIntervals) {
      if (!interval.endTime.isAfter(dayStart) ||
          !interval.startTime.isBefore(dayEnd)) {
        continue;
      }

      final start = interval.startTime.isBefore(dayStart)
          ? dayStart
          : interval.startTime;
      final end = interval.endTime.isAfter(dayEnd)
          ? dayEnd
          : interval.endTime;

      if (end.isAfter(start)) {
        clipped.add(
          FocusInterval(
            startTime: start,
            endTime: end,
          ),
        );
      }
    }

    if (clipped.isEmpty) {
      return Duration.zero;
    }

    clipped.sort(
      (a, b) => a.startTime.compareTo(b.startTime),
    );

    var currentStart = clipped.first.startTime;
    var currentEnd = clipped.first.endTime;
    var total = Duration.zero;

    for (var index = 1; index < clipped.length; index++) {
      final interval = clipped[index];

      if (!interval.startTime.isAfter(currentEnd)) {
        if (interval.endTime.isAfter(currentEnd)) {
          currentEnd = interval.endTime;
        }
        continue;
      }

      total += currentEnd.difference(currentStart);
      currentStart = interval.startTime;
      currentEnd = interval.endTime;
    }

    total += currentEnd.difference(currentStart);
    return total;
  }

  // ---------------------------------------------------------
  // ACTIVE SESSION GETTERS
  // ---------------------------------------------------------

  List<FocusBlock> get plan {
    return List<FocusBlock>.unmodifiable(_plan);
  }

  FocusBlock? get currentBlock {
    if (_plan.isEmpty) {
      return null;
    }

    if (_currentBlockIndex < 0 ||
        _currentBlockIndex >= _plan.length) {
      return null;
    }

    return _plan[_currentBlockIndex];
  }

  String? get taskId => _taskId;
  String get taskName => _taskName;
  DateTime? get taskOccurrenceDate => _taskOccurrenceDate;
  DateTime? get taskScheduledStart => _taskScheduledStart;
  DateTime? get taskScheduledEnd => _taskScheduledEnd;
  DateTime? get sessionStartedAt => _sessionStartedAt;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get sessionFinished => _sessionFinished;

  bool get isBreak {
    return currentBlock?.isBreak ?? false;
  }

  bool get isFocus {
    return currentBlock?.isFocus ?? false;
  }

  int get remainingSeconds => _remainingSeconds;

  int get completedFocusBlocks {
    return _completedFocusBlocks;
  }

  int get totalFocusBlocks {
    return _plan.where((block) => block.isFocus).length;
  }

  int get currentFocusBlockNumber {
    if (isFocus) {
      return _completedFocusBlocks + 1;
    }

    return _completedFocusBlocks;
  }

  double get currentBlockProgress {
    if (_currentBlockTotalSeconds <= 0) {
      return 0;
    }

    final completedSeconds =
        _currentBlockTotalSeconds - _remainingSeconds;

    return (completedSeconds / _currentBlockTotalSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// The session that just finished during this app runtime.
  ///
  /// FocusCompleteScreen uses this so reopening the app does not
  /// accidentally pretend an old stored session has just completed.
  FocusSession? get lastSession {
    return _lastSession;
  }

  bool isFocusingTaskOccurrence(String taskId, DateTime occurrenceDate) {
    if (!_isRunning || _taskId != taskId) return false;
    final linked = _taskOccurrenceDate ?? _sessionStartedAt;
    if (linked == null) return false;
    return _sameDateLocal(linked, occurrenceDate);
  }

  List<FocusInterval> get currentFocusIntervalsSnapshot {
    final intervals = <FocusInterval>[..._focusIntervals];
    final openStart = _currentFocusIntervalStart;
    if (_isRunning && !_isPaused && isFocus && openStart != null) {
      final now = _now();
      if (now.isAfter(openStart)) {
        intervals.add(FocusInterval(startTime: openStart, endTime: now));
      }
    }
    return List<FocusInterval>.unmodifiable(intervals);
  }

  Duration get currentActiveFocusDuration {
    return currentFocusIntervalsSnapshot.fold(Duration.zero, (total, interval) {
      return total + interval.duration;
    });
  }

  // ---------------------------------------------------------
  // START SESSION
  // ---------------------------------------------------------

  void startSession({
    String? taskId,
    required String taskName,
    DateTime? taskOccurrenceDate,
    DateTime? taskScheduledStart,
    DateTime? taskScheduledEnd,
    required int totalFocusMinutes,
    required int focusBlockMinutes,
    required int breakMinutes,
  }) {
    if (_isRunning) {
      throw StateError(
        'A focus session is already running.',
      );
    }

    if (taskId != null && taskId.trim().isEmpty) {
      throw ArgumentError('Task id cannot be empty when provided.');
    }

    if ((taskScheduledStart == null) != (taskScheduledEnd == null)) {
      throw ArgumentError(
        'Task schedule snapshot start and end must exist together.',
      );
    }
    if (taskScheduledStart != null &&
        taskScheduledEnd != null &&
        !taskScheduledEnd.isAfter(taskScheduledStart)) {
      throw ArgumentError('Task schedule snapshot end must be after start.');
    }
    if (taskId == null &&
        (taskOccurrenceDate != null || taskScheduledStart != null)) {
      throw ArgumentError(
        'Task occurrence metadata requires a linked task id.',
      );
    }

    if (taskName.trim().isEmpty) {
      throw ArgumentError('Task name cannot be empty.');
    }

    if (totalFocusMinutes <= 0) {
      throw ArgumentError(
        'Total focus duration must be greater than zero.',
      );
    }

    if (focusBlockMinutes <= 0) {
      throw ArgumentError(
        'Focus block duration must be greater than zero.',
      );
    }

    if (breakMinutes < 0) {
      throw ArgumentError(
        'Break duration cannot be negative.',
      );
    }

    _taskId = taskId;
    _taskName = taskName;
    _taskOccurrenceDate = taskOccurrenceDate == null
        ? null
        : _dateOnlyLocal(taskOccurrenceDate);
    _taskScheduledStart = taskScheduledStart;
    _taskScheduledEnd = taskScheduledEnd;

    _plan = _buildPlan(
      totalFocusMinutes: totalFocusMinutes,
      focusBlockMinutes: focusBlockMinutes,
      breakMinutes: breakMinutes,
    );

    _currentBlockIndex = 0;

    _remainingSeconds = 0;
    _currentBlockTotalSeconds = 0;

    _isRunning = true;
    _isPaused = false;
    _sessionFinished = false;

    _completedFocusBlocks = 0;

    _focusIntervals.clear();
    _pauseIntervals.clear();
    _breakIntervals.clear();

    _currentFocusIntervalStart = null;
    _currentPauseIntervalStart = null;
    _currentBreakIntervalStart = null;

    _lastSession = null;
    _lastPersistenceError = null;
    _lastPersistenceErrorSessionId = null;

    _sessionStartedAt = _now();

    _plannedFocusDuration =
        Duration(minutes: totalFocusMinutes);

    _beginCurrentBlock(
      startAt: _sessionStartedAt!,
    );

    _startTicker();

    notifyListeners();
  }

  // ---------------------------------------------------------
  // BUILD SESSION PLAN
  // ---------------------------------------------------------

  List<FocusBlock> _buildPlan({
    required int totalFocusMinutes,
    required int focusBlockMinutes,
    required int breakMinutes,
  }) {
    final blocks = <FocusBlock>[];

    var remainingFocusMinutes = totalFocusMinutes;

    while (remainingFocusMinutes > 0) {
      final currentFocusMinutes =
          remainingFocusMinutes >= focusBlockMinutes
              ? focusBlockMinutes
              : remainingFocusMinutes;

      blocks.add(
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(
            minutes: currentFocusMinutes,
          ),
        ),
      );

      remainingFocusMinutes -= currentFocusMinutes;

      if (remainingFocusMinutes > 0 &&
          breakMinutes > 0) {
        blocks.add(
          FocusBlock(
            type: FocusBlockType.breakTime,
            duration: Duration(
              minutes: breakMinutes,
            ),
          ),
        );
      }
    }

    return blocks;
  }

  // ---------------------------------------------------------
  // START CURRENT BLOCK
  // ---------------------------------------------------------

  void _beginCurrentBlock({
    required DateTime startAt,
  }) {
    final block = currentBlock;

    if (block == null) {
      return;
    }

    _currentBlockTotalSeconds =
        block.duration.inSeconds;

    _remainingSeconds =
        block.duration.inSeconds;

    _blockDeadline =
        startAt.add(block.duration);

    _currentFocusIntervalStart = null;
    _currentBreakIntervalStart = null;

    if (block.isFocus) {
      _currentFocusIntervalStart = startAt;
    } else {
      _currentBreakIntervalStart = startAt;
    }
  }

  // ---------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _tick();
      },
    );
  }

  void _tick() {
    if (!_isRunning || _isPaused) {
      return;
    }

    final now = _now();

    while (_isRunning && !_isPaused) {
      final deadline = _blockDeadline;

      if (deadline == null) {
        return;
      }

      if (now.isBefore(deadline)) {
        _remainingSeconds =
            _secondsUntil(deadline, now);

        notifyListeners();

        return;
      }

      _remainingSeconds = 0;

      final transitionTime = deadline;

      _completeCurrentBlockAt(
        transitionTime,
      );
    }
  }

  int _secondsUntil(
    DateTime end,
    DateTime now,
  ) {
    final milliseconds =
        end.difference(now).inMilliseconds;

    if (milliseconds <= 0) {
      return 0;
    }

    return (milliseconds + 999) ~/ 1000;
  }

  // ---------------------------------------------------------
  // BLOCK FINISHED
  // ---------------------------------------------------------

  void _completeCurrentBlockAt(
    DateTime transitionTime,
  ) {
    final block = currentBlock;

    if (block == null) {
      return;
    }

    if (block.isFocus) {
      _closeCurrentFocusInterval(
        transitionTime,
      );

      _completedFocusBlocks++;
    } else {
      _closeCurrentBreakInterval(
        transitionTime,
      );
    }

    final isLastBlock =
        _currentBlockIndex == _plan.length - 1;

    if (isLastBlock) {
      _finishSession(
        endAt: transitionTime,
        completedNaturally: true,
      );

      return;
    }

    _currentBlockIndex++;

    _beginCurrentBlock(
      startAt: transitionTime,
    );
  }

  // ---------------------------------------------------------
  // PAUSE
  // ---------------------------------------------------------

  void pauseSession() {
    if (!_isRunning || _isPaused) {
      return;
    }

    final now = _now();
    final deadline = _blockDeadline;

    if (deadline != null) {
      _remainingSeconds =
          _secondsUntil(deadline, now);
    }

    if (isFocus) {
      _closeCurrentFocusInterval(now);
    } else if (isBreak) {
      _closeCurrentBreakInterval(now);
    }

    _currentPauseIntervalStart = now;

    _isPaused = true;
    _blockDeadline = null;

    notifyListeners();
  }

  // ---------------------------------------------------------
  // RESUME
  // ---------------------------------------------------------

  void resumeSession() {
    if (!_isRunning || !_isPaused) {
      return;
    }

    final now = _now();

    _closeCurrentPauseInterval(now);

    _isPaused = false;

    _blockDeadline = now.add(
      Duration(seconds: _remainingSeconds),
    );

    if (isFocus) {
      _currentFocusIntervalStart = now;
    } else if (isBreak) {
      _currentBreakIntervalStart = now;
    }

    notifyListeners();
  }

  // ---------------------------------------------------------
  // SKIP BREAK
  // ---------------------------------------------------------

  void skipBreak() {
    if (!_isRunning || !isBreak || _isPaused) {
      return;
    }

    final now = _now();

    _closeCurrentBreakInterval(now);

    final isLastBlock =
        _currentBlockIndex == _plan.length - 1;

    if (isLastBlock) {
      _finishSession(
        endAt: now,
        completedNaturally: true,
      );

      return;
    }

    _currentBlockIndex++;

    _beginCurrentBlock(
      startAt: now,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------
  // END SESSION EARLY
  // ---------------------------------------------------------

  void endSession() {
    if (!_isRunning) {
      return;
    }

    _finishSession(
      endAt: _now(),
      completedNaturally: false,
    );
  }

  // ---------------------------------------------------------
  // INTERVAL TRACKING
  // ---------------------------------------------------------

  void _closeCurrentFocusInterval(
    DateTime endTime,
  ) {
    final startTime =
        _currentFocusIntervalStart;

    if (startTime == null) {
      return;
    }

    if (endTime.isAfter(startTime)) {
      _focusIntervals.add(
        FocusInterval(
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    _currentFocusIntervalStart = null;
  }

  void _closeCurrentPauseInterval(
    DateTime endTime,
  ) {
    final startTime =
        _currentPauseIntervalStart;

    if (startTime == null) {
      return;
    }

    if (endTime.isAfter(startTime)) {
      _pauseIntervals.add(
        FocusInterval(
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    _currentPauseIntervalStart = null;
  }

  void _closeCurrentBreakInterval(
    DateTime endTime,
  ) {
    final startTime =
        _currentBreakIntervalStart;

    if (startTime == null) {
      return;
    }

    if (endTime.isAfter(startTime)) {
      _breakIntervals.add(
        FocusInterval(
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }

    _currentBreakIntervalStart = null;
  }

  // ---------------------------------------------------------
  // FINISH SESSION
  // ---------------------------------------------------------

  void _finishSession({
    required DateTime endAt,
    required bool completedNaturally,
  }) {
    _ticker?.cancel();
    _ticker = null;

    if (_isPaused) {
      _closeCurrentPauseInterval(endAt);
    } else if (isFocus) {
      _closeCurrentFocusInterval(endAt);
    } else if (isBreak) {
      _closeCurrentBreakInterval(endAt);
    }

    final startedAt =
        _sessionStartedAt ?? endAt;

    final session = FocusSession(
      id: startedAt.microsecondsSinceEpoch.toString(),
      taskId: _taskId,
      taskName: _taskName,
      taskOccurrenceDate: _taskOccurrenceDate,
      taskScheduledStart: _taskScheduledStart,
      taskScheduledEnd: _taskScheduledEnd,
      startedAt: startedAt,
      endedAt: endAt,
      plannedFocusDuration:
          _plannedFocusDuration,
      plan: List<FocusBlock>.unmodifiable(
        _plan,
      ),
      focusIntervals:
          List<FocusInterval>.unmodifiable(
        _focusIntervals,
      ),
      pauseIntervals:
          List<FocusInterval>.unmodifiable(
        _pauseIntervals,
      ),
      breakIntervals:
          List<FocusInterval>.unmodifiable(
        _breakIntervals,
      ),
      completedFocusBlocks:
          _completedFocusBlocks,
      completedNaturally:
          completedNaturally,
    );

    _lastSession = session;

    _upsertHistory(session);
    _queuePersistence(session);

    _isRunning = false;
    _isPaused = false;
    _sessionFinished = true;

    _remainingSeconds = 0;
    _blockDeadline = null;

    _currentFocusIntervalStart = null;
    _currentPauseIntervalStart = null;
    _currentBreakIntervalStart = null;

    notifyListeners();
  }

  void _upsertHistory(
    FocusSession session,
  ) {
    _sessionHistory.removeWhere(
      (existing) => existing.id == session.id,
    );

    _sessionHistory.add(session);

    _sortSessionHistory();
  }

  void _sortSessionHistory() {
    _sessionHistory.sort(
      (a, b) => b.endedAt.compareTo(a.endedAt),
    );
  }

  void _queuePersistence(
    FocusSession session,
  ) {
    final storage = _storageService;

    if (storage == null) {
      return;
    }

    final previousWrite = _pendingPersistence;
    final currentWrite = _persistSession(
      storage,
      session,
    );

    // The current Hive write starts immediately. The combined future still
    // lets callers wait until every write that was pending at this point
    // has finished.
    _pendingPersistence = Future.wait<void>([
      previousWrite,
      currentWrite,
    ]).then((_) {});
  }

  Future<void> _persistSession(
    FocusSessionStorageService storage,
    FocusSession session,
  ) async {
    try {
      await storage.saveSession(session);

      if (_lastSession?.id == session.id) {
        _lastPersistenceError = null;
        _lastPersistenceErrorSessionId = null;
      }
    } catch (error, stackTrace) {
      if (_lastSession?.id == session.id) {
        _lastPersistenceError =
            'Focus history could not be saved.';
        _lastPersistenceErrorSessionId = session.id;
      }

      debugPrint(
        'Focus session persistence failed: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

DateTime _dateOnlyLocal(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return DateTime(local.year, local.month, local.day);
}


bool _sameDateLocal(DateTime first, DateTime second) {
  final a = _dateOnlyLocal(first);
  final b = _dateOnlyLocal(second);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

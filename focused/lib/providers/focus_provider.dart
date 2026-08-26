import 'dart:async';

import 'package:flutter/material.dart';

import '../models/focus_block.dart';
import '../models/focus_session.dart';

class FocusProvider extends ChangeNotifier {
  Timer? _ticker;

  List<FocusBlock> _plan = [];

  int _currentBlockIndex = 0;

  int _remainingSeconds = 0;
  int _currentBlockTotalSeconds = 0;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _sessionFinished = false;

  String _taskName = '';

  DateTime? _sessionStartedAt;
  DateTime? _blockDeadline;

  DateTime? _currentFocusIntervalStart;

  Duration _plannedFocusDuration = Duration.zero;

  final List<FocusInterval> _focusIntervals = [];

  int _completedFocusBlocks = 0;

  FocusSession? _lastSession;

  // -----------------------
  // GETTERS
  // -----------------------

  List<FocusBlock> get plan {
    return List.unmodifiable(_plan);
  }

  FocusBlock? get currentBlock {
    if (_plan.isEmpty) {
      return null;
    }

    if (_currentBlockIndex < 0 || _currentBlockIndex >= _plan.length) {
      return null;
    }

    return _plan[_currentBlockIndex];
  }

  String get taskName => _taskName;

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

    final completedSeconds = _currentBlockTotalSeconds - _remainingSeconds;

    return (completedSeconds / _currentBlockTotalSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  FocusSession? get lastSession {
    return _lastSession;
  }

  // -----------------------
  // START SESSION
  // -----------------------

  void startSession({
    required String taskName,
    required int totalFocusMinutes,
    required int focusBlockMinutes,
    required int breakMinutes,
  }) {
    if (totalFocusMinutes <= 0) {
      throw ArgumentError('Total focus duration must be greater than zero.');
    }

    if (focusBlockMinutes <= 0) {
      throw ArgumentError('Focus block duration must be greater than zero.');
    }

    _ticker?.cancel();

    _taskName = taskName;

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

    _lastSession = null;

    _sessionStartedAt = DateTime.now();

    _plannedFocusDuration = Duration(minutes: totalFocusMinutes);

    _beginCurrentBlock(startAt: _sessionStartedAt!);

    _startTicker();

    notifyListeners();
  }

  // -----------------------
  // BUILD SESSION PLAN
  // -----------------------

  List<FocusBlock> _buildPlan({
    required int totalFocusMinutes,
    required int focusBlockMinutes,
    required int breakMinutes,
  }) {
    final List<FocusBlock> blocks = [];

    int remainingFocusMinutes = totalFocusMinutes;

    while (remainingFocusMinutes > 0) {
      final currentFocusMinutes = remainingFocusMinutes >= focusBlockMinutes
          ? focusBlockMinutes
          : remainingFocusMinutes;

      blocks.add(
        FocusBlock(
          type: FocusBlockType.focus,
          duration: Duration(minutes: currentFocusMinutes),
        ),
      );

      remainingFocusMinutes -= currentFocusMinutes;

      if (remainingFocusMinutes > 0 && breakMinutes > 0) {
        blocks.add(
          FocusBlock(
            type: FocusBlockType.breakTime,
            duration: Duration(minutes: breakMinutes),
          ),
        );
      }
    }

    return blocks;
  }

  // -----------------------
  // START CURRENT BLOCK
  // -----------------------

  void _beginCurrentBlock({required DateTime startAt}) {
    final block = currentBlock;

    if (block == null) {
      return;
    }

    _currentBlockTotalSeconds = block.duration.inSeconds;

    _remainingSeconds = block.duration.inSeconds;

    _blockDeadline = startAt.add(block.duration);

    if (block.isFocus) {
      _currentFocusIntervalStart = startAt;
    } else {
      _currentFocusIntervalStart = null;
    }
  }

  // -----------------------
  // TIMER
  // -----------------------

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _tick() {
    if (!_isRunning || _isPaused) {
      return;
    }

    final now = DateTime.now();

    while (_isRunning && !_isPaused) {
      final deadline = _blockDeadline;

      if (deadline == null) {
        return;
      }

      if (now.isBefore(deadline)) {
        _remainingSeconds = _secondsUntil(deadline, now);

        notifyListeners();

        return;
      }

      _remainingSeconds = 0;

      final transitionTime = deadline;

      _completeCurrentBlockAt(transitionTime);
    }
  }

  int _secondsUntil(DateTime end, DateTime now) {
    final milliseconds = end.difference(now).inMilliseconds;

    if (milliseconds <= 0) {
      return 0;
    }

    return (milliseconds + 999) ~/ 1000;
  }

  // -----------------------
  // BLOCK FINISHED
  // -----------------------

  void _completeCurrentBlockAt(DateTime transitionTime) {
    final block = currentBlock;

    if (block == null) {
      return;
    }

    if (block.isFocus) {
      _closeCurrentFocusInterval(transitionTime);

      _completedFocusBlocks++;
    }

    final isLastBlock = _currentBlockIndex == _plan.length - 1;

    if (isLastBlock) {
      _finishSession(endAt: transitionTime, completedNaturally: true);

      return;
    }

    _currentBlockIndex++;

    _beginCurrentBlock(startAt: transitionTime);
  }

  // -----------------------
  // PAUSE
  // -----------------------

  void pauseSession() {
    if (!_isRunning || _isPaused) {
      return;
    }

    final now = DateTime.now();

    final deadline = _blockDeadline;

    if (deadline != null) {
      _remainingSeconds = _secondsUntil(deadline, now);
    }

    if (isFocus) {
      _closeCurrentFocusInterval(now);
    }

    _isPaused = true;

    _blockDeadline = null;

    notifyListeners();
  }

  // -----------------------
  // RESUME
  // -----------------------

  void resumeSession() {
    if (!_isRunning || !_isPaused) {
      return;
    }

    final now = DateTime.now();

    _isPaused = false;

    _blockDeadline = now.add(Duration(seconds: _remainingSeconds));

    if (isFocus) {
      _currentFocusIntervalStart = now;
    }

    notifyListeners();
  }

  // -----------------------
  // SKIP BREAK
  // -----------------------

  void skipBreak() {
    if (!_isRunning || !isBreak) {
      return;
    }

    final now = DateTime.now();

    final isLastBlock = _currentBlockIndex == _plan.length - 1;

    if (isLastBlock) {
      _finishSession(endAt: now, completedNaturally: true);

      return;
    }

    _currentBlockIndex++;

    _beginCurrentBlock(startAt: now);

    notifyListeners();
  }

  // -----------------------
  // END SESSION EARLY
  // -----------------------

  void endSession() {
    if (!_isRunning) {
      return;
    }

    _finishSession(endAt: DateTime.now(), completedNaturally: false);
  }

  // -----------------------
  // FOCUS INTERVAL
  // -----------------------

  void _closeCurrentFocusInterval(DateTime endTime) {
    final startTime = _currentFocusIntervalStart;

    if (startTime == null) {
      return;
    }

    if (endTime.isAfter(startTime)) {
      _focusIntervals.add(
        FocusInterval(startTime: startTime, endTime: endTime),
      );
    }

    _currentFocusIntervalStart = null;
  }

  // -----------------------
  // FINISH SESSION
  // -----------------------

  void _finishSession({
    required DateTime endAt,
    required bool completedNaturally,
  }) {
    _ticker?.cancel();
    _ticker = null;

    if (isFocus) {
      _closeCurrentFocusInterval(endAt);
    }

    final startedAt = _sessionStartedAt ?? endAt;

    _lastSession = FocusSession(
      id: startedAt.microsecondsSinceEpoch.toString(),
      taskName: _taskName,
      startedAt: startedAt,
      endedAt: endAt,
      plannedFocusDuration: _plannedFocusDuration,
      plan: List<FocusBlock>.unmodifiable(_plan),
      focusIntervals: List<FocusInterval>.unmodifiable(_focusIntervals),
      completedFocusBlocks: _completedFocusBlocks,
      completedNaturally: completedNaturally,
    );

    _isRunning = false;
    _isPaused = false;
    _sessionFinished = true;

    _remainingSeconds = 0;
    _blockDeadline = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

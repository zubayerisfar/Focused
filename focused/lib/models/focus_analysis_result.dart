import 'focus_interruption.dart';

class FocusAnalysisResult {
  final DateTime focusStart;
  final DateTime focusEnd;

  /// What the user originally planned.
  final Duration plannedDuration;

  /// Time the focus timer was genuinely active.
  /// Pauses and breaks are excluded.
  final Duration actualFocusDuration;

  /// Unique distracting time during active focus.
  /// Overlapping distraction intervals are NOT double-counted.
  final Duration distractedDuration;

  /// actualFocusDuration - distractedDuration
  final Duration effectiveFocusDuration;

  /// Number of continuous distraction episodes.
  final int interruptionCount;

  /// actualFocus / plannedFocus, percentage points 0-100.
  final double completionRate;

  /// effectiveFocus / actualFocus, percentage points 0-100.
  final double attentionRetention;

  /// effectiveFocus / plannedFocus, percentage points 0-100.
  final double focusQuality;

  final String? topInterrupterApp;
  final Map<String, Duration> distractionByApp;
  final List<FocusInterruption> interruptions;

  const FocusAnalysisResult({
    required this.focusStart,
    required this.focusEnd,
    required this.plannedDuration,
    required this.actualFocusDuration,
    required this.distractedDuration,
    required this.effectiveFocusDuration,
    required this.interruptionCount,
    required this.completionRate,
    required this.attentionRetention,
    required this.focusQuality,
    required this.topInterrupterApp,
    required this.distractionByApp,
    required this.interruptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 1,
      'focusStart': focusStart.toIso8601String(),
      'focusEnd': focusEnd.toIso8601String(),
      'plannedSeconds': plannedDuration.inSeconds,
      'actualSeconds': actualFocusDuration.inSeconds,
      'distractedSeconds': distractedDuration.inSeconds,
      'effectiveSeconds': effectiveFocusDuration.inSeconds,
      'interruptionCount': interruptionCount,
      'completionRate': completionRate,
      'attentionRetention': attentionRetention,
      'focusQuality': focusQuality,
      'topInterrupterApp': topInterrupterApp,
      'distractionByApp': distractionByApp.map(
        (key, value) => MapEntry(key, value.inSeconds),
      ),
      'interruptions': interruptions
          .map((interruption) => interruption.toMap())
          .toList(growable: false),
    };
  }

  factory FocusAnalysisResult.fromMap(Map<dynamic, dynamic> map) {
    final version = map['schemaVersion'];
    if (version is! num || version.toInt() != 1) {
      throw const FormatException('Unsupported focus analysis schema.');
    }

    DateTime requiredDate(String key) {
      final raw = map[key];
      if (raw is! String) {
        throw FormatException('Missing $key.');
      }
      final value = DateTime.tryParse(raw);
      if (value == null) {
        throw FormatException('Invalid $key.');
      }
      return value;
    }

    int nonNegativeInt(String key) {
      final raw = map[key];
      if (raw is! num || raw.toInt() < 0) {
        throw FormatException('Invalid $key.');
      }
      return raw.toInt();
    }

    double number(String key) {
      final raw = map[key];
      if (raw is! num) {
        throw FormatException('Invalid $key.');
      }
      return raw.toDouble();
    }

    final focusStart = requiredDate('focusStart');
    final focusEnd = requiredDate('focusEnd');
    if (focusEnd.isBefore(focusStart)) {
      throw const FormatException('Focus analysis end precedes start.');
    }

    final distractionRaw = map['distractionByApp'];
    final distractionByApp = <String, Duration>{};
    if (distractionRaw is Map) {
      for (final entry in distractionRaw.entries) {
        if (entry.key is String && entry.value is num) {
          final seconds = (entry.value as num).toInt();
          if (seconds >= 0) {
            distractionByApp[entry.key as String] = Duration(seconds: seconds);
          }
        }
      }
    }

    final interruptions = <FocusInterruption>[];
    final interruptionsRaw = map['interruptions'];
    if (interruptionsRaw is List) {
      for (final item in interruptionsRaw) {
        if (item is Map) {
          interruptions.add(FocusInterruption.fromMap(item));
        }
      }
    }

    final topRaw = map['topInterrupterApp'];

    return FocusAnalysisResult(
      focusStart: focusStart,
      focusEnd: focusEnd,
      plannedDuration: Duration(seconds: nonNegativeInt('plannedSeconds')),
      actualFocusDuration: Duration(seconds: nonNegativeInt('actualSeconds')),
      distractedDuration:
          Duration(seconds: nonNegativeInt('distractedSeconds')),
      effectiveFocusDuration:
          Duration(seconds: nonNegativeInt('effectiveSeconds')),
      interruptionCount: nonNegativeInt('interruptionCount'),
      completionRate: number('completionRate'),
      attentionRetention: number('attentionRetention'),
      focusQuality: number('focusQuality'),
      topInterrupterApp: topRaw is String && topRaw.trim().isNotEmpty
          ? topRaw
          : null,
      distractionByApp: Map.unmodifiable(distractionByApp),
      interruptions: List.unmodifiable(interruptions),
    );
  }
}

import 'package:hive_ce/hive_ce.dart';

import '../models/focus_analysis_result.dart';

class StoredFocusAnalysis {
  final String sessionId;
  final DateTime savedAt;
  final FocusAnalysisResult analysis;

  const StoredFocusAnalysis({
    required this.sessionId,
    required this.savedAt,
    required this.analysis,
  });
}

abstract class FocusAnalysisStore {
  Future<void> init();
  List<StoredFocusAnalysis> loadAll();
  Future<void> saveAnalysis(
    String sessionId,
    FocusAnalysisResult analysis, {
    DateTime? savedAt,
  });
  Future<void> deleteAnalysis(String sessionId);
}

class FocusAnalysisStorageService implements FocusAnalysisStore {
  static const String _boxName = 'focused_focus_analyses_v1';
  static const int _schemaVersion = 1;

  Box<dynamic>? _box;

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _requiredBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'FocusAnalysisStorageService.init() must be called first.',
      );
    }
    return box;
  }

  @override
  List<StoredFocusAnalysis> loadAll() {
    final values = <StoredFocusAnalysis>[];

    for (final key in _requiredBox.keys) {
      final raw = _requiredBox.get(key);
      if (key is! String || raw is! Map) {
        continue;
      }

      try {
        final version = raw['schemaVersion'];
        if (version is! num || version.toInt() != _schemaVersion) {
          continue;
        }

        final savedAtRaw = raw['savedAt'];
        final analysisRaw = raw['analysis'];
        if (savedAtRaw is! String || analysisRaw is! Map) {
          continue;
        }

        final savedAt = DateTime.tryParse(savedAtRaw);
        if (savedAt == null) {
          continue;
        }

        values.add(
          StoredFocusAnalysis(
            sessionId: key,
            savedAt: savedAt,
            analysis: FocusAnalysisResult.fromMap(analysisRaw),
          ),
        );
      } catch (_) {
        // Ignore malformed historical entries so one damaged row does not
        // disable wellbeing analytics. A future successful analysis for the
        // same session id will replace it.
      }
    }

    values.sort((a, b) => b.analysis.focusEnd.compareTo(a.analysis.focusEnd));
    return List<StoredFocusAnalysis>.unmodifiable(values);
  }

  @override
  Future<void> saveAnalysis(
    String sessionId,
    FocusAnalysisResult analysis, {
    DateTime? savedAt,
  }) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Focus analysis session id cannot be empty.');
    }

    await _requiredBox.put(normalized, {
      'schemaVersion': _schemaVersion,
      'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
      'analysis': analysis.toMap(),
    });
  }

  @override
  Future<void> deleteAnalysis(String sessionId) async {
    await _requiredBox.delete(sessionId);
  }
}

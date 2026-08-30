import 'package:hive_ce/hive_ce.dart';

import '../models/focus_session.dart';

class FocusSessionStorageService {
  static const String _boxName = 'focused_focus_sessions';

  Box<dynamic>? _box;

  bool get isInitialized {
    return _box != null && _box!.isOpen;
  }

  Future<void> init() async {
    if (isInitialized) {
      return;
    }

    _box = await Hive.openBox<dynamic>(_boxName);
  }

  List<FocusSession> loadSessions() {
    final box = _requireBox();
    final sessions = <FocusSession>[];

    for (final value in box.values) {
      if (value is! Map) {
        continue;
      }

      try {
        sessions.add(
          FocusSession.fromMap(
            Map<dynamic, dynamic>.from(value),
          ),
        );
      } on FormatException {
        // Ignore one malformed local/development record rather than
        // crashing the whole app during startup.
      } on ArgumentError {
        // Same principle as task storage.
      }
    }

    sessions.sort(
      (a, b) => b.endedAt.compareTo(a.endedAt),
    );

    return sessions;
  }

  Future<void> saveSession(FocusSession session) async {
    final box = _requireBox();

    // The stable session id makes this idempotent and prevents duplicate
    // history rows if the same finished session is saved twice.
    await box.put(
      session.id,
      session.toMap(),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final box = _requireBox();
    await box.delete(sessionId);
  }

  Future<void> clearAll() async {
    final box = _requireBox();
    await box.clear();
  }

  Box<dynamic> _requireBox() {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError(
        'FocusSessionStorageService has not been initialized.',
      );
    }

    return box;
  }
}

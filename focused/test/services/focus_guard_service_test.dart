import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/focus_guard_status.dart';
import 'package:focused/services/focus_guard_service.dart';

void main() {
  test('noop Focus Guard is safe on unsupported platforms/tests', () async {
    const guard = NoopFocusGuardController();

    final status = await guard.getFocusGuardStatus();
    final events = await guard.getFocusGuardEvents();

    expect(status.isSupported, isFalse);
    expect(status.phase, FocusGuardPhase.inactive);
    expect(events, isEmpty);
  });
}

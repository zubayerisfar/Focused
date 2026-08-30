import 'package:flutter_test/flutter_test.dart';
import 'package:focused/models/focus_guard_event.dart';

void main() {
  test('FocusGuardEvent parses persisted native warning payload', () {
    final event = FocusGuardEvent.fromMap({
      'id': 'event-1',
      'sessionId': 'session-1',
      'type': 'workspaceWarning',
      'occurredAtMs': 1788105600000,
      'packageName': 'com.google.android.youtube',
      'appLabel': 'YouTube',
      'outsideWorkspaceSeconds': 30,
      'message': 'Return to focus.',
    });

    expect(event.id, 'event-1');
    expect(event.sessionId, 'session-1');
    expect(event.type, FocusGuardEventType.workspaceWarning);
    expect(event.packageName, 'com.google.android.youtube');
    expect(event.appLabel, 'YouTube');
    expect(event.outsideWorkspaceSeconds, 30);
    expect(event.message, 'Return to focus.');
  });
}

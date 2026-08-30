enum FocusGuardEventType {
  workspaceWarning,
  focusBlockComplete,
  breakComplete,
  sessionComplete,
  unknown,
}

class FocusGuardEvent {
  final String id;
  final String sessionId;
  final FocusGuardEventType type;
  final DateTime occurredAt;
  final String? packageName;
  final String? appLabel;
  final int? outsideWorkspaceSeconds;
  final String message;

  const FocusGuardEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.occurredAt,
    required this.message,
    this.packageName,
    this.appLabel,
    this.outsideWorkspaceSeconds,
  });

  factory FocusGuardEvent.fromMap(Map<dynamic, dynamic> map) {
    return FocusGuardEvent(
      id: (map['id'] as String?) ?? '',
      sessionId: (map['sessionId'] as String?) ?? '',
      type: _eventTypeFromString(map['type'] as String?),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        (map['occurredAtMs'] as num?)?.toInt() ?? 0,
      ),
      packageName: map['packageName'] as String?,
      appLabel: map['appLabel'] as String?,
      outsideWorkspaceSeconds:
          (map['outsideWorkspaceSeconds'] as num?)?.toInt(),
      message: (map['message'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type.name,
      'occurredAtMs': occurredAt.millisecondsSinceEpoch,
      'packageName': packageName,
      'appLabel': appLabel,
      'outsideWorkspaceSeconds': outsideWorkspaceSeconds,
      'message': message,
    };
  }
}

FocusGuardEventType _eventTypeFromString(String? value) {
  for (final type in FocusGuardEventType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return FocusGuardEventType.unknown;
}

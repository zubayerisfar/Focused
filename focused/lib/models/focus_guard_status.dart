enum FocusGuardPhase {
  inactive,
  focus,
  breakTime,
  paused,
  unknown,
}

class FocusGuardStatus {
  final bool isSupported;
  final bool serviceRunning;
  final bool usageAccessGranted;
  final bool notificationsEnabled;
  final String? sessionId;
  final String? originDevice;
  final String? taskName;
  final FocusGuardPhase phase;
  final int remainingSeconds;
  final int warningThresholdSeconds;
  final String? currentPackage;

  const FocusGuardStatus({
    required this.isSupported,
    required this.serviceRunning,
    required this.usageAccessGranted,
    required this.notificationsEnabled,
    required this.phase,
    required this.remainingSeconds,
    required this.warningThresholdSeconds,
    this.sessionId,
    this.originDevice,
    this.taskName,
    this.currentPackage,
  });

  const FocusGuardStatus.unsupported()
      : isSupported = false,
        serviceRunning = false,
        usageAccessGranted = false,
        notificationsEnabled = false,
        sessionId = null,
        originDevice = null,
        taskName = null,
        phase = FocusGuardPhase.inactive,
        remainingSeconds = 0,
        warningThresholdSeconds = 30,
        currentPackage = null;

  factory FocusGuardStatus.fromMap(Map<dynamic, dynamic> map) {
    return FocusGuardStatus(
      isSupported: map['isSupported'] == true,
      serviceRunning: map['serviceRunning'] == true,
      usageAccessGranted: map['usageAccessGranted'] == true,
      notificationsEnabled: map['notificationsEnabled'] == true,
      sessionId: map['sessionId'] as String?,
      originDevice: map['originDevice'] as String?,
      taskName: map['taskName'] as String?,
      phase: _phaseFromString(map['phase'] as String?),
      remainingSeconds: (map['remainingSeconds'] as num?)?.toInt() ?? 0,
      warningThresholdSeconds:
          (map['warningThresholdSeconds'] as num?)?.toInt() ?? 30,
      currentPackage: map['currentPackage'] as String?,
    );
  }
}

FocusGuardPhase _phaseFromString(String? value) {
  switch (value) {
    case 'focus':
      return FocusGuardPhase.focus;
    case 'break':
    case 'breakTime':
      return FocusGuardPhase.breakTime;
    case 'paused':
      return FocusGuardPhase.paused;
    case 'inactive':
      return FocusGuardPhase.inactive;
    default:
      return FocusGuardPhase.unknown;
  }
}

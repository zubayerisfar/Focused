class NotificationEvent {
  const NotificationEvent({
    required this.packageName,
    required this.timestamp,
    required this.notificationKey,
  });

  final String packageName;
  final DateTime timestamp;
  final String notificationKey;

  factory NotificationEvent.fromMap(Map<dynamic, dynamic> map) {
    final packageName = map['packageName'];
    final timestampMillis = map['timestampMillis'];
    final notificationKey = map['notificationKey'];

    if (packageName is! String ||
        packageName.trim().isEmpty ||
        timestampMillis is! num ||
        notificationKey is! String ||
        notificationKey.trim().isEmpty) {
      throw const FormatException('Invalid notification event.');
    }

    return NotificationEvent(
      packageName: packageName,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        timestampMillis.toInt(),
      ),
      notificationKey: notificationKey,
    );
  }
}

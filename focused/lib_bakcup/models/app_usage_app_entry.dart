import 'dart:typed_data';

class AppUsageAppEntry {
  final String appId;
  final String appName;
  final Duration duration;
  final Uint8List? iconBytes;

  const AppUsageAppEntry({
    required this.appId,
    required this.appName,
    required this.duration,
    this.iconBytes,
  });
}

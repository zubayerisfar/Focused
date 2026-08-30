import 'dart:typed_data';

class AppMetadata {
  final String packageName;
  final String displayName;
  final Uint8List? iconBytes;
  final bool isInstalled;
  final DateTime updatedAt;

  const AppMetadata({
    required this.packageName,
    required this.displayName,
    required this.iconBytes,
    required this.isInstalled,
    required this.updatedAt,
  });

  bool get hasIcon => iconBytes != null && iconBytes!.isNotEmpty;

  AppMetadata copyWith({
    String? displayName,
    Uint8List? iconBytes,
    bool? isInstalled,
    DateTime? updatedAt,
  }) {
    return AppMetadata(
      packageName: packageName,
      displayName: displayName ?? this.displayName,
      iconBytes: iconBytes ?? this.iconBytes,
      isInstalled: isInstalled ?? this.isInstalled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toStorageMap() {
    return {
      'schemaVersion': 1,
      'packageName': packageName,
      'displayName': displayName,
      'iconBytes': iconBytes?.toList(growable: false),
      'isInstalled': isInstalled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppMetadata.fromStorageMap(Map<dynamic, dynamic> map) {
    final packageName = map['packageName'];
    final displayName = map['displayName'];
    final installed = map['isInstalled'];
    final updatedAtRaw = map['updatedAt'];

    if (packageName is! String || packageName.trim().isEmpty) {
      throw const FormatException('Invalid app metadata packageName.');
    }
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const FormatException('Invalid app metadata displayName.');
    }
    if (installed is! bool || updatedAtRaw is! String) {
      throw const FormatException('Invalid app metadata fields.');
    }

    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (updatedAt == null) {
      throw const FormatException('Invalid app metadata updatedAt.');
    }

    Uint8List? iconBytes;
    final rawIcon = map['iconBytes'];
    if (rawIcon is List) {
      final values = <int>[];
      for (final item in rawIcon) {
        if (item is! num) {
          values.clear();
          break;
        }
        final value = item.toInt();
        if (value < 0 || value > 255) {
          values.clear();
          break;
        }
        values.add(value);
      }
      if (values.isNotEmpty) {
        iconBytes = Uint8List.fromList(values);
      }
    } else if (rawIcon is Uint8List && rawIcon.isNotEmpty) {
      iconBytes = Uint8List.fromList(rawIcon);
    }

    return AppMetadata(
      packageName: packageName,
      displayName: displayName,
      iconBytes: iconBytes,
      isInstalled: installed,
      updatedAt: updatedAt,
    );
  }

  factory AppMetadata.fromPlatformMap(
    Map<dynamic, dynamic> map, {
    DateTime? fetchedAt,
  }) {
    final packageName = map['packageName'];
    final displayName = map['displayName'];
    final installed = map['isInstalled'];

    if (packageName is! String || packageName.trim().isEmpty) {
      throw const FormatException('Invalid native app packageName.');
    }

    Uint8List? iconBytes;
    final rawIcon = map['iconBytes'];
    if (rawIcon is Uint8List && rawIcon.isNotEmpty) {
      iconBytes = Uint8List.fromList(rawIcon);
    } else if (rawIcon is List) {
      final ints = rawIcon.whereType<num>().map((value) => value.toInt()).toList();
      if (ints.isNotEmpty && ints.every((value) => value >= 0 && value <= 255)) {
        iconBytes = Uint8List.fromList(ints);
      }
    }

    final normalizedName =
        displayName is String && displayName.trim().isNotEmpty
            ? displayName.trim()
            : packageName;

    return AppMetadata(
      packageName: packageName,
      displayName: normalizedName,
      iconBytes: iconBytes,
      isInstalled: installed is bool ? installed : false,
      updatedAt: fetchedAt ?? DateTime.now(),
    );
  }
}

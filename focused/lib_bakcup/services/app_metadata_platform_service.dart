import 'dart:io';

import 'package:flutter/services.dart';

import '../models/app_metadata.dart';

abstract class AppMetadataPlatformService {
  bool get isSupported;

  Future<List<AppMetadata>> loadMetadata(
    Iterable<String> packageNames, {
    int iconSize = 96,
  });
}

class AndroidAppMetadataService implements AppMetadataPlatformService {
  AndroidAppMetadataService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'focused/app_metadata';

  final MethodChannel _channel;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<List<AppMetadata>> loadMetadata(
    Iterable<String> packageNames, {
    int iconSize = 96,
  }) async {
    if (!isSupported) {
      return const <AppMetadata>[];
    }

    final packages = packageNames
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (packages.isEmpty) {
      return const <AppMetadata>[];
    }

    final raw = await _channel.invokeMethod<List<dynamic>>(
      'getAppMetadataBatch',
      {
        'packageNames': packages,
        'iconSize': iconSize.clamp(48, 192),
      },
    );

    if (raw == null || raw.isEmpty) {
      return const <AppMetadata>[];
    }

    final fetchedAt = DateTime.now();
    final result = <AppMetadata>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      try {
        result.add(
          AppMetadata.fromPlatformMap(
            item,
            fetchedAt: fetchedAt,
          ),
        );
      } catch (_) {
        // One bad native result must not prevent the remaining app metadata
        // from being shown.
      }
    }

    return List<AppMetadata>.unmodifiable(result);
  }
}

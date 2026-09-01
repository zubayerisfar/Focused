import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class AndroidDeviceIdentity {
  const AndroidDeviceIdentity({
    required this.manufacturer,
    required this.brand,
    required this.model,
  });

  final String manufacturer;
  final String brand;
  final String model;

  String get fingerprint {
    final value =
        '${manufacturer.trim().toLowerCase()}|${brand.trim().toLowerCase()}|${model.trim().toLowerCase()}';
    return _simpleHash(value);
  }

  static String _simpleHash(String value) {
    var hash = 2166136261;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  String get friendlyName {
    final cleanModel = model.trim();
    final cleanManufacturer = manufacturer.trim();
    final cleanBrand = brand.trim();

    if (cleanModel.isEmpty) {
      final fallback = cleanManufacturer.isNotEmpty
          ? cleanManufacturer
          : cleanBrand;
      return fallback.isEmpty ? 'Android device' : _capitalized(fallback);
    }

    final maker = cleanManufacturer.isNotEmpty ? cleanManufacturer : cleanBrand;
    if (maker.isEmpty) return cleanModel;

    final modelLower = cleanModel.toLowerCase();
    final makerLower = maker.toLowerCase();
    final brandLower = cleanBrand.toLowerCase();

    // Many OEMs already include their name in Build.MODEL, for example
    // "Infinix X6833B". Avoid producing "Infinix Infinix X6833B".
    if (modelLower.startsWith(makerLower) ||
        (brandLower.isNotEmpty && modelLower.startsWith(brandLower))) {
      return cleanModel;
    }

    return '${_capitalized(maker)} $cleanModel';
  }

  static String _capitalized(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    if (clean.length == 1) return clean.toUpperCase();
    return '${clean[0].toUpperCase()}${clean.substring(1)}';
  }
}

class AndroidInstallationInfoService {
  static const MethodChannel _channel = MethodChannel(
    'focused/installation_info',
  );

  Future<DateTime?> firstInstallTime() async {
    if (!Platform.isAndroid) return null;

    try {
      final millis = await _channel.invokeMethod<int>(
        'getFirstInstallTimeMillis',
      );
      if (millis == null || millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<AndroidDeviceIdentity?> deviceIdentity() async {
    if (!Platform.isAndroid) return null;

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceIdentity',
      );
      if (raw == null) return null;
      return AndroidDeviceIdentity(
        manufacturer: (raw['manufacturer'] as String?) ?? '',
        brand: (raw['brand'] as String?) ?? '',
        model: (raw['model'] as String?) ?? '',
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String?> friendlyDeviceName() async {
    final identity = await deviceIdentity();
    return identity?.friendlyName;
  }
}

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

    final maker = cleanManufacturer.isNotEmpty
        ? cleanManufacturer
        : cleanBrand;
    if (maker.isEmpty) return cleanModel;

    final modelLower = cleanModel.toLowerCase();
    final makerLower = maker.toLowerCase();
    final brandLower = cleanBrand.toLowerCase();

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

class DeviceInfoService {
  static const MethodChannel _channel = MethodChannel(
    'focused/installation_info',
  );

  Future<AndroidDeviceIdentity?> getDeviceIdentity() async {
    if (!Platform.isAndroid) return null;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceIdentity',
      );
      if (data == null) return null;
      return AndroidDeviceIdentity(
        manufacturer: (data['manufacturer'] as String?) ?? '',
        brand: (data['brand'] as String?) ?? '',
        model: (data['model'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> friendlyDeviceName() async {
    if (!Platform.isAndroid) {
      return Platform.isIOS ? 'iPhone/iPad' : 'Focused device';
    }
    final identity = await getDeviceIdentity();
    return identity?.friendlyName ?? 'Android device';
  }
}

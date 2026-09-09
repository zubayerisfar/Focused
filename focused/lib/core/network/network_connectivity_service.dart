import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  NetworkConnectivityService({bool enablePolling = true}) {
    if (enablePolling) {
      _init();
    }
  }

  static final NetworkConnectivityService _instance =
      NetworkConnectivityService();

  static NetworkConnectivityService get instance => _instance;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  Timer? _pollTimer;
  bool _isChecking = false;

  void _init() {
    checkNow();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkNow();
    });
  }

  Future<bool> checkNow() async {
    if (_isChecking) return isOnlineNotifier.value;
    _isChecking = true;
    try {
      final isOnline = await hasInternetConnection();
      if (isOnlineNotifier.value != isOnline) {
        isOnlineNotifier.value = isOnline;
      }
      return isOnline;
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(milliseconds: 2500));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

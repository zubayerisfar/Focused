import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NetworkConnectivityService {
  const NetworkConnectivityService();

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
}

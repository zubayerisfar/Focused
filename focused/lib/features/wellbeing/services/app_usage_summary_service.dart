import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUsageSummaryService {
  const AppUsageSummaryService();

  static const MethodChannel _channel = MethodChannel('focused/usage_summary');

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('cancelDailySummaries');
      await _channel.invokeMethod('setEnabled', {'enabled': false});
    } catch (e) {
      debugPrint('Could not cancel AppUsageSummaryService: $e');
    }
  }

  Future<bool> isEnabled() async {
    return false;
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Could not update AppUsageSummaryService status: $e');
    }
  }

  Future<void> showTestSummaryNow() async {
    try {
      await _channel.invokeMethod('showTestSummaryNow');
    } catch (e) {
      debugPrint('Could not trigger test AppUsageSummary notification: $e');
    }
  }
}

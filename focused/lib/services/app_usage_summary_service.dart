import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUsageSummaryService {
  const AppUsageSummaryService();

  static const MethodChannel _channel = MethodChannel('focused/usage_summary');

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('scheduleDailySummaries');
    } catch (e) {
      debugPrint('Could not initialize AppUsageSummaryService: $e');
    }
  }

  Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isEnabled');
      return result ?? true;
    } catch (e) {
      debugPrint('Could not check AppUsageSummaryService status: $e');
      return true;
    }
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

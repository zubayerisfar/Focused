import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetService {
  static const _channel = MethodChannel('focused/home_widget');

  static Future<void> updateWidgetData({
    required String screenTimeFormatted,
    required String comparisonText,
    required String streakText,
    required String focusHoursText,
    required List<Map<String, dynamic>> tasks,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('updateWidgetData', {
        'screenTime': screenTimeFormatted,
        'comparison': comparisonText,
        'streak': streakText,
        'focusHours': focusHoursText,
        'tasks': tasks,
      });
    } catch (e) {
      debugPrint('HomeWidget update failed: $e');
    }
  }
}

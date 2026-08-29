import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/models/app_usage_record.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/screens/wellbeing/app_usage_app_details_screen.dart';
import 'package:focused/services/usage_stats_service.dart';

void main() {
  testWidgets('app history screen exposes ranges and classification',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = UsageProvider(
      usageStatsService: _UnsupportedUsageService(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: AppUsageAppDetailsScreen(
            appId: 'com.example.app',
            initialAppName: 'Example',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usage history'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);
    expect(find.text('14d'), findsOneWidget);
    expect(find.text('30d'), findsOneWidget);
    expect(find.text('90d'), findsOneWidget);
    expect(find.text('Productive'), findsOneWidget);
    expect(find.text('Neutral'), findsAtLeastNWidgets(1));
    expect(find.text('Distracting'), findsOneWidget);
  });
}

class _UnsupportedUsageService implements UsageStatsService {
  @override
  bool get isSupported => false;

  @override
  Future<bool> hasUsageAccess() async => false;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  ) async {
    return const [];
  }
}

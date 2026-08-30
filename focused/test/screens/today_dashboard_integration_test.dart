import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/models/app_usage_record.dart';
import 'package:focused/models/habit.dart';
import 'package:focused/models/task.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/habit_provider.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/screens/today/today_screen.dart';
import 'package:focused/services/usage_stats_service.dart';
import 'package:focused/theme/app_theme.dart';

void main() {
  testWidgets(
    'Today combines real usage summary plan timeline and separate habits',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);

      final taskProvider = TaskProvider();
      await taskProvider.createTask(
        title: 'Deep work block',
        priority: TaskPriority.important,
        plannedDate: dayStart,
        scheduledStart: dayStart.add(const Duration(hours: 10)),
        scheduledEnd: dayStart.add(const Duration(hours: 11)),
        createdAt: dayStart,
      );

      final habitProvider = HabitProvider();
      await habitProvider.createHabit(
        title: 'Read',
        goalType: HabitGoalType.count,
        targetValue: 20,
        unit: 'pages',
        weekdays: {now.weekday},
        iconCodePoint: Icons.menu_book_rounded.codePoint,
        colorValue: AppTheme.success.value,
        createdAt: dayStart,
      );

      final usageProvider = UsageProvider(
        usageStatsService: _TodayUsageService(now: now),
      );
      await usageProvider.refreshPermissionAndUsage(
        now: now,
        force: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: taskProvider),
            ChangeNotifierProvider(create: (_) => FocusProvider()),
            ChangeNotifierProvider.value(value: usageProvider),
            ChangeNotifierProvider.value(value: habitProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(
              body: TodayScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today at a glance'), findsOneWidget);
      expect(find.text('Most used apps'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('DAILY PLAN'), findsOneWidget);
      expect(find.text('Deep work block'), findsOneWidget);
      expect(find.text('Plan execution'), findsOneWidget);

      // Habits intentionally live below the calendar/execution section.
      // Scroll the real Today viewport rather than depending on Sliver cache
      // extent to decide whether those lazy children are mounted.
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();

      expect(find.text('DAILY HABITS'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    },
  );
}

class _TodayUsageService implements UsageStatsService {
  _TodayUsageService({required this.now});

  final DateTime now;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasUsageAccess() async => true;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<List<AppUsageRecord>> queryUsageRecords(
    DateTime start,
    DateTime end,
  ) async {
    if (start.year != now.year ||
        start.month != now.month ||
        start.day != now.day) {
      return const [];
    }

    final dayStart = DateTime(now.year, now.month, now.day);
    final latestSafeEnd = now.isAfter(dayStart.add(const Duration(hours: 3)))
        ? now
        : dayStart.add(const Duration(hours: 3));

    return [
      AppUsageRecord(
        appId: 'com.instagram.android',
        appName: 'Instagram',
        startTime: dayStart.add(const Duration(hours: 1)),
        endTime: dayStart.add(const Duration(hours: 2)),
      ),
      AppUsageRecord(
        appId: 'com.android.chrome',
        appName: 'Chrome',
        startTime: dayStart.add(const Duration(hours: 2)),
        endTime: latestSafeEnd,
      ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/models/task.dart';
import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/habit_provider.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/screens/planner/planner_screen.dart';
import 'package:focused/theme/app_theme.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildPlanner() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(
          body: PlannerScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'Planner calendar menu exposes Schedule Day 3 days Week Month',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(buildPlanner());
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsWidgets);

      await tester.tap(find.byTooltip('Change calendar view'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    },
  );

  testWidgets(
    'Day view renders a real hourly calendar grid',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(buildPlanner());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Change calendar view'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(find.text('No timed tasks on this day.'), findsOneWidget);
      expect(find.text('6 AM'), findsOneWidget);
    },
  );

  testWidgets(
    'Month view exposes previous and next month navigation',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(buildPlanner());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Change calendar view'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('planner-month-previous')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('planner-month-next')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('planner-month-next')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'active scheduled task is labelled IN FOCUS',
    (tester) async {
      await usePhoneViewport(tester);

      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final taskProvider = TaskProvider();
      final task = await taskProvider.createTask(
        title: 'Active research',
        priority: TaskPriority.important,
        scheduledStart: day.add(const Duration(hours: 8)),
        scheduledEnd: day.add(const Duration(hours: 9)),
        createdAt: day,
      );
      final focusProvider = FocusProvider();
      focusProvider.startSession(
        taskId: task.id,
        taskName: task.title,
        taskOccurrenceDate: day,
        taskScheduledStart: task.scheduledStart,
        taskScheduledEnd: task.scheduledEnd,
        totalFocusMinutes: 30,
        focusBlockMinutes: 30,
        breakMinutes: 5,
      );
      addTearDown(focusProvider.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: taskProvider),
            ChangeNotifierProvider.value(value: focusProvider),
            ChangeNotifierProvider(create: (_) => HabitProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(body: PlannerScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Active research'), findsOneWidget);
      expect(find.text('IN FOCUS'), findsOneWidget);
    },
  );

  testWidgets(
    'Planner uses one contextual create action',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(buildPlanner());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('New habit'), findsNothing);

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New habit'), findsOneWidget);
      expect(find.text('New task'), findsNothing);
    },
  );
}

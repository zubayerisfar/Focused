import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/habit_provider.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/screens/main/main_shell.dart';
import 'package:focused/screens/focus/focus_screen.dart';
import 'package:focused/screens/planner/planner_screen.dart';
import 'package:focused/screens/today/today_screen.dart';
import 'package:focused/theme/app_theme.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: const MainShell(),
      ),
    );
  }

  testWidgets('main navigation contains only Today Planner Focus',
      (tester) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // These controls are always onstage, so normal finders are deliberately
    // used. Traversing every offstage viewport is unnecessary and made the old
    // test brittle with IndexedStack + scrollable destinations.
    expect(find.byKey(const ValueKey('nav-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-planner')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-focus')), findsOneWidget);

    expect(find.byKey(const ValueKey('nav-calendar')), findsNothing);
    expect(find.byKey(const ValueKey('nav-habits')), findsNothing);
    expect(find.byKey(const ValueKey('nav-insights')), findsNothing);
  });

  testWidgets('Planner exposes Tasks and Habits as internal sections',
      (tester) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-planner')));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('New habit'), findsNothing);

    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();

    expect(find.text('New habit'), findsOneWidget);
    expect(find.text('New task'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Today Planner and Focus switch cleanly at phone viewport',
      (tester) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Any uncaught layout/render exception automatically fails a widget test;
    // explicit takeException() calls are not needed and can hide the original
    // exception behind a "Multiple exceptions" aggregate.
    await tester.tap(find.byKey(const ValueKey('nav-planner')));
    await tester.pumpAndSettle();
    expect(find.byType(PlannerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-focus')));
    await tester.pumpAndSettle();
    expect(find.byType(FocusScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}

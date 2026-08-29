import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/providers/focus_provider.dart';
import 'package:focused/providers/habit_provider.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/providers/usage_provider.dart';
import 'package:focused/screens/focus/focus_screen.dart';
import 'package:focused/screens/planner/planner_screen.dart';
import 'package:focused/screens/today/today_screen.dart';
import 'package:focused/theme/app_theme.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(body: PrimaryScrollController.none(child: child)),
      ),
    );
  }

  testWidgets('Today renders at phone size', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const TodayScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('Planner renders at phone size', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const PlannerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('Today renders on a narrower phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const TodayScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('Today at a glance'), findsOneWidget);
  });

  testWidgets('Planner header fits a narrower phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PlannerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('Focus renders at phone size', (tester) async {
    await phone(tester);
    await tester.pumpWidget(app(const FocusScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Focus'), findsOneWidget);
  });
}

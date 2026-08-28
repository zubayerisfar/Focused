import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:focused/providers/habit_provider.dart';
import 'package:focused/providers/task_provider.dart';
import 'package:focused/screens/planner/planner_screen.dart';

void main() {
  Widget buildPlanner() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: PlannerScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'Planner calendar menu exposes Schedule Day 3 days Week Month',
    (tester) async {
      await tester.pumpWidget(buildPlanner());

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
    'Planner uses one contextual create action',
    (tester) async {
      await tester.pumpWidget(buildPlanner());

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

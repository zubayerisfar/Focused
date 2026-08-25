import 'package:go_router/go_router.dart';

import '../screens/calendar/event_edit_screen.dart';
import '../screens/main/main_shell.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tasks/task_edit_screen.dart';
import '../screens/habits/habit_details_screen.dart';
import '../screens/habits/habit_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MainShell()),

    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    GoRoute(
      path: '/task/new',
      builder: (context, state) => const TaskEditScreen(),
    ),

    GoRoute(
      path: '/calendar/event/new',
      builder: (context, state) {
        return const EventEditScreen();
      },
    ),

    GoRoute(
      path: '/calendar/event/edit',
      builder: (context, state) {
        return const EventEditScreen(isEditing: true);
      },
    ),
    GoRoute(
      path: '/habit/new',
      builder: (context, state) {
        return const HabitEditScreen();
      },
    ),

    GoRoute(
      path: '/habit/details',
      builder: (context, state) {
        return const HabitDetailsScreen();
      },
    ),

    GoRoute(
      path: '/habit/edit',
      builder: (context, state) {
        return const HabitEditScreen(isEditing: true);
      },
    ),
  ],
);

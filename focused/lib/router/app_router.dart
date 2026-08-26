import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';

import '../screens/main/main_shell.dart';

import '../screens/settings/settings_screen.dart';

import '../screens/devices/devices_screen.dart';

import '../screens/tasks/task_edit_screen.dart';

import '../screens/calendar/event_edit_screen.dart';

import '../screens/habits/habit_details_screen.dart';
import '../screens/habits/habit_edit_screen.dart';

import '../screens/focus/focus_setup_screen.dart';
import '../screens/focus/focus_session_screen.dart';
import '../screens/focus/focus_complete_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',

  routes: [
    // Main application
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const MainShell();
      },
    ),

    // Authentication
    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginScreen();
      },
    ),

    // Settings
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        return const SettingsScreen();
      },
    ),

    // Devices
    GoRoute(
      path: '/devices',
      builder: (context, state) {
        return const DevicesScreen();
      },
    ),

    // Tasks
    GoRoute(
      path: '/task/new',
      builder: (context, state) {
        return const TaskEditScreen();
      },
    ),

    // Calendar
    GoRoute(
      path: '/calendar/event/new',
      builder: (context, state) {
        return const EventEditScreen();
      },
    ),

    GoRoute(
      path: '/calendar/event/edit',
      builder: (context, state) {
        return const EventEditScreen(
          isEditing: true,
        );
      },
    ),

    // Habits
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
        return const HabitEditScreen(
          isEditing: true,
        );
      },
    ),

    // Focus
    GoRoute(
      path: '/focus/setup',
      builder: (context, state) {
        return const FocusSetupScreen();
      },
    ),

    GoRoute(
      path: '/focus/session',
      builder: (context, state) {
        return const FocusSessionScreen();
      },
    ),

    GoRoute(
      path: '/focus/complete',
      builder: (context, state) {
        return const FocusCompleteScreen();
      },
    ),
  ],
);
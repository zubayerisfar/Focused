import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/calendar/event_edit_screen.dart';
import '../screens/devices/devices_screen.dart';
import '../screens/focus/focus_complete_screen.dart';
import '../screens/focus/focus_session_screen.dart';
import '../screens/focus/focus_setup_screen.dart';
import '../screens/habits/habit_details_screen.dart';
import '../screens/habits/habit_edit_screen.dart';
import '../screens/main/main_shell.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tasks/task_edit_screen.dart';
import '../screens/wellbeing/app_usage_details_screen.dart';
import '../screens/wellbeing/focus_interruption_details_screen.dart';
import '../screens/wellbeing/usage_permission_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const DevicesScreen(),
    ),
    GoRoute(
      path: '/task/new',
      builder: (context, state) => const TaskEditScreen(),
    ),
    GoRoute(
      path: '/task/edit/:taskId',
      builder: (context, state) => TaskEditScreen(
        taskId: state.pathParameters['taskId'],
      ),
    ),
    GoRoute(
      path: '/calendar/event/new',
      builder: (context, state) => const EventEditScreen(),
    ),
    GoRoute(
      path: '/calendar/event/edit',
      builder: (context, state) => const EventEditScreen(isEditing: true),
    ),
    GoRoute(
      path: '/habit/new',
      builder: (context, state) => const HabitEditScreen(),
    ),
    GoRoute(
      path: '/habit/details',
      builder: (context, state) => const HabitDetailsScreen(),
    ),
    GoRoute(
      path: '/habit/edit',
      builder: (context, state) => const HabitEditScreen(isEditing: true),
    ),
    GoRoute(
      path: '/focus/setup',
      builder: (context, state) => FocusSetupScreen(
        initialTaskId: state.uri.queryParameters['taskId'],
      ),
    ),
    GoRoute(
      path: '/focus/session',
      builder: (context, state) => const FocusSessionScreen(),
    ),
    GoRoute(
      path: '/focus/complete',
      builder: (context, state) => const FocusCompleteScreen(),
    ),
    GoRoute(
      path: '/wellbeing/app-usage',
      builder: (context, state) => const AppUsageDetailsScreen(),
    ),
    GoRoute(
      path: '/wellbeing/focus-interruptions',
      builder: (context, state) => const FocusInterruptionDetailsScreen(),
    ),
    GoRoute(
      path: '/wellbeing/permission',
      builder: (context, state) => const UsagePermissionScreen(),
    ),
  ],
);

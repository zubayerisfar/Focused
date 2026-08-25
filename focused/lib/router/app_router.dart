import 'package:go_router/go_router.dart';

import '../screens/main/main_shell.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tasks/task_edit_screen.dart';

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
  ],
);

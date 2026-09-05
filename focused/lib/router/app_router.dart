import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../models/friend_user.dart';
import '../providers/account_provider.dart';
import '../providers/onboarding_provider.dart';
import '../features/auth/views/login_screen.dart';
import '../features/devices/views/devices_screen.dart';
import '../features/focus/views/focus_complete_screen.dart';
import '../features/focus/views/focus_session_details_screen.dart';
import '../features/focus/views/focus_session_screen.dart';
import '../features/focus/views/focus_setup_screen.dart';
import '../features/friends/views/add_friends_screen.dart';
import '../features/friends/views/friends_screen.dart';
import '../features/habits/views/habit_details_screen.dart';
import '../features/habits/views/habit_edit_screen.dart';
import '../features/main/views/main_shell.dart';
import '../features/onboarding/views/intro_sequence_screen.dart';
import '../features/onboarding/views/ad_notice_screen.dart';
import '../features/profile/views/badges_screen.dart';
import '../features/profile/views/profile_screen.dart';
import '../features/reminders/views/reminder_edit_screen.dart';
import '../features/settings/views/notification_access_screen.dart';
import '../features/settings/views/notification_permission_screen.dart';
import '../features/settings/views/cloud_sync_screen.dart';
import '../features/settings/views/settings_screen.dart';
import '../features/streak/views/streak_screen.dart';
import '../features/tasks/views/task_details_screen.dart';
import '../features/tasks/views/task_edit_screen.dart';
import '../features/wellbeing/views/app_limits_screen.dart';
import '../features/wellbeing/views/app_usage_app_details_screen.dart';
import '../features/wellbeing/views/app_usage_details_screen.dart';
import '../features/wellbeing/views/daily_wellbeing_details_screen.dart';
import '../features/wellbeing/views/focus_interruption_details_screen.dart';
import '../features/wellbeing/views/usage_permission_screen.dart';
import '../features/wellbeing/views/wellbeing_screen.dart';
import '../features/wellbeing/views/wellbeing_summary_screen.dart';
import '../features/wellbeing/views/weekly_wellbeing_screen.dart';
import '../features/xp/views/xp_screen.dart';

GoRouter createAppRouter({
  required AccountProvider accountProvider,
  required OnboardingProvider onboardingProvider,
}) {
  final refresh = _RouterRefreshNotifier([accountProvider, onboardingProvider]);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.matchedLocation;

      if (!onboardingProvider.introSeen) {
        return path == '/intro' ? null : '/intro';
      }

      if (!accountProvider.isInitialized) {
        return null;
      }

      if (!accountProvider.isSignedIn) {
        return path == '/login' ? null : '/login';
      }

      // Show ad notice exactly once after signing in for the first time
      if (!onboardingProvider.adNoticeSeen) {
        return path == '/ad-notice' ? null : '/ad-notice';
      }

      if (path == '/login' || path == '/intro' || path == '/ad-notice') {
        return '/';
      }

      final uri = state.uri;
      if (uri.scheme == 'focused') {
        final host = uri.host;
        final rawPath = host.isNotEmpty ? '/$host${uri.path}' : uri.path;
        if (rawPath.startsWith('/tasks/edit') ||
            rawPath.startsWith('/task/new') ||
            rawPath == '/task') {
          return '/task/new';
        }
        if (rawPath.startsWith('/tasks/detail') ||
            rawPath.startsWith('/task/')) {
          final id =
              uri.queryParameters['id'] ??
              (uri.pathSegments.length > 1 ? uri.pathSegments[1] : null);
          return (id != null && id.isNotEmpty) ? '/task/$id' : '/task/new';
        }
        if (rawPath.startsWith('/focus/setup')) {
          return '/focus/setup';
        }
        if (rawPath.startsWith('/today') || rawPath == '/' || rawPath.isEmpty) {
          return '/';
        }
        return rawPath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/intro',
        builder: (context, state) => const IntroSequenceScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => MainShell(
          key: ValueKey(state.uri.toString()),
          initialIndex: _mainTabIndex(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/ad-notice',
        builder: (context, state) => const AdNoticeScreen(),
      ),
      GoRoute(path: '/xp', builder: (context, state) => const XpScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfileScreen(
          friendUser: state.extra is FriendUser
              ? state.extra as FriendUser
              : null,
        ),
      ),
      GoRoute(
        path: '/profile/view',
        builder: (context, state) => ProfileScreen(
          friendUser: state.extra is FriendUser
              ? state.extra as FriendUser
              : null,
        ),
      ),
      GoRoute(
        path: '/streak',
        builder: (context, state) => const StreakScreen(),
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return FriendsScreen(initialTabIndex: tab == 'followers' ? 1 : 0);
        },
      ),
      GoRoute(
        path: '/friends/add',
        builder: (context, state) => const AddFriendsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/cloud-sync',
        builder: (context, state) => const CloudSyncScreen(),
      ),
      GoRoute(
        path: '/settings/notification-permission',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(
        path: '/settings/notification-access',
        builder: (context, state) => const NotificationAccessScreen(),
      ),
      GoRoute(
        path: '/wellbeing',
        builder: (context, state) => const WellbeingScreen(),
      ),
      GoRoute(
        path: '/wellbeing/day',
        builder: (context, state) {
          final raw = state.uri.queryParameters['date'];
          final parsed = DateTime.tryParse(raw ?? '');
          final date = parsed == null
              ? DateTime.now()
              : DateTime(parsed.year, parsed.month, parsed.day);
          return DailyWellbeingDetailsScreen(date: date);
        },
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
        path: '/tasks/edit',
        builder: (context, state) => const TaskEditScreen(),
      ),
      GoRoute(
        path: '/tasks/detail',
        builder: (context, state) {
          final id =
              state.uri.queryParameters['id'] ??
              state.uri.queryParameters['taskId'];
          if (id != null && id.isNotEmpty) {
            return TaskDetailsScreen(taskId: id);
          }
          return const TaskEditScreen();
        },
      ),
      GoRoute(
        path: '/task/:taskId',
        builder: (context, state) => TaskDetailsScreen(
          taskId: Uri.decodeComponent(state.pathParameters['taskId']!),
          occurrenceDate: _parseDateOnly(state.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/task/edit/:taskId',
        builder: (context, state) =>
            TaskEditScreen(taskId: state.pathParameters['taskId']),
      ),
      GoRoute(
        path: '/reminder/new',
        builder: (context, state) => const ReminderEditScreen(),
      ),
      GoRoute(
        path: '/reminder/edit/:reminderId',
        builder: (context, state) =>
            ReminderEditScreen(reminderId: state.pathParameters['reminderId']),
      ),
      GoRoute(
        path: '/habit/new',
        builder: (context, state) => const HabitEditScreen(),
      ),
      GoRoute(
        path: '/habit/:habitId',
        builder: (context, state) =>
            HabitDetailsScreen(habitId: state.pathParameters['habitId']!),
      ),
      GoRoute(
        path: '/habit/edit/:habitId',
        builder: (context, state) =>
            HabitEditScreen(habitId: state.pathParameters['habitId']),
      ),
      GoRoute(
        path: '/focus/setup',
        builder: (context, state) => FocusSetupScreen(
          initialTaskId: state.uri.queryParameters['taskId'],
          initialOccurrenceDate: _parseDateOnly(
            state.uri.queryParameters['occurrenceDate'],
          ),
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
        path: '/focus/history/:sessionId',
        builder: (context, state) => FocusSessionDetailsScreen(
          sessionId: Uri.decodeComponent(state.pathParameters['sessionId']!),
        ),
      ),
      GoRoute(
        path: '/wellbeing/summary',
        builder: (context, state) => const WellbeingSummaryScreen(),
      ),
      GoRoute(
        path: '/wellbeing/analytics',
        builder: (context, state) => const WeeklyWellbeingScreen(),
      ),
      GoRoute(
        path: '/wellbeing/app-usage',
        builder: (context, state) => const AppUsageDetailsScreen(),
      ),
      GoRoute(
        path: '/wellbeing/app/:appId',
        builder: (context, state) => AppUsageAppDetailsScreen(
          appId: Uri.decodeComponent(state.pathParameters['appId']!),
          initialAppName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/wellbeing/focus-interruptions',
        builder: (context, state) => const FocusInterruptionDetailsScreen(),
      ),
      GoRoute(
        path: '/wellbeing/permission',
        builder: (context, state) => const UsagePermissionScreen(),
      ),
      GoRoute(
        path: '/wellbeing/limits',
        builder: (context, state) => const AppLimitsScreen(),
      ),
    ],
  );
}

int _mainTabIndex(String? raw) {
  switch (raw) {
    case 'planner':
      return 1;
    case 'focus':
      return 2;
    case 'friends':
      return 3;
    case 'settings':
      return 4;
    case 'home':
    default:
      return 0;
  }
}

DateTime? _parseDateOnly(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final local = parsed.isUtc ? parsed.toLocal() : parsed;
  return DateTime(local.year, local.month, local.day);
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._sources) {
    for (final source in _sources) {
      source.addListener(_notify);
    }
  }

  final List<Listenable> _sources;

  void _notify() => notifyListeners();

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(_notify);
    }
    super.dispose();
  }
}

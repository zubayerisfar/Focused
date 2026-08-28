import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/focus_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'providers/user_profile_provider.dart';
import 'services/android_usage_stats_service.dart';
import 'services/focus_session_storage_service.dart';
import 'services/habit_storage_service.dart';
import 'services/task_notification_service.dart';
import 'services/task_occurrence_completion_storage_service.dart';
import 'services/task_storage_service.dart';
import 'services/usage_record_storage_service.dart';
import 'services/user_profile_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();
  final occurrenceCompletionStorage = TaskOccurrenceCompletionStorageService();
  final focusSessionStorageService = FocusSessionStorageService();
  final usageRecordStorageService = UsageRecordStorageService();
  final habitStorageService = HabitStorageService();
  final userProfileStorageService = UserProfileStorageService();

  await taskStorageService.init();
  await occurrenceCompletionStorage.init();
  await focusSessionStorageService.init();
  await usageRecordStorageService.init();
  await habitStorageService.init();
  await userProfileStorageService.init();

  final taskNotificationService = TaskNotificationService();

  final taskProvider = TaskProvider(
    storageService: taskStorageService,
    notificationService: taskNotificationService,
    occurrenceCompletionStorage: occurrenceCompletionStorage,
  );
  await taskProvider.loadStoredTasks();

  final focusProvider = FocusProvider(
    storageService: focusSessionStorageService,
  );
  await focusProvider.loadStoredSessions();

  final usageProvider = UsageProvider(
    usageStatsService: AndroidUsageStatsService(),
    storageService: usageRecordStorageService,
  );
  await usageProvider.loadStoredUsage();

  final habitProvider = HabitProvider(storageService: habitStorageService);
  await habitProvider.loadStoredHabits();

  final userProfileProvider = UserProfileProvider(
    storageService: userProfileStorageService,
  );
  await userProfileProvider.loadStoredProfile();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: usageProvider),
        ChangeNotifierProvider.value(value: focusProvider),
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider.value(value: habitProvider),
        ChangeNotifierProvider.value(value: userProfileProvider),
      ],
      child: const FocusProductivityApp(),
    ),
  );

  unawaited(usageProvider.refreshPermissionAndUsage());
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/focus_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'services/android_usage_stats_service.dart';
import 'services/focus_session_storage_service.dart';
import 'services/task_notification_service.dart';
import 'services/task_occurrence_completion_storage_service.dart';
import 'services/task_storage_service.dart';
import 'services/usage_record_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();
  final occurrenceCompletionStorage =
      TaskOccurrenceCompletionStorageService();
  final focusSessionStorageService = FocusSessionStorageService();
  final usageRecordStorageService = UsageRecordStorageService();

  await taskStorageService.init();
  await occurrenceCompletionStorage.init();
  await focusSessionStorageService.init();
  await usageRecordStorageService.init();

  // ---------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------

  final taskNotificationService = TaskNotificationService();

  // ---------------------------------------------------------
  // PROVIDERS WITH STORED DATA
  // ---------------------------------------------------------

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

  // Load local snapshots first so the UI can render immediately. The native
  // Android permission check/query runs after the app has started.
  await usageProvider.loadStoredUsage();

  // ---------------------------------------------------------
  // START APP
  // ---------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider.value(
          value: usageProvider,
        ),
        ChangeNotifierProvider.value(
          value: focusProvider,
        ),
        ChangeNotifierProvider.value(
          value: taskProvider,
        ),
      ],
      child: const FocusProductivityApp(),
    ),
  );

  // Do not block first paint on UsageStats. If access was already granted,
  // today/yesterday are refreshed in the background.
  unawaited(usageProvider.refreshPermissionAndUsage());
}

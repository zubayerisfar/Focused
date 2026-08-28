import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/focus_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'services/focus_session_storage_service.dart';
import 'services/task_notification_service.dart';
import 'services/task_occurrence_completion_storage_service.dart';
import 'services/task_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();
  final occurrenceCompletionStorage =
      TaskOccurrenceCompletionStorageService();
  final focusSessionStorageService =
      FocusSessionStorageService();

  await taskStorageService.init();
  await occurrenceCompletionStorage.init();
  await focusSessionStorageService.init();

  // ---------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------
  //
  // IMPORTANT:
  // Do NOT await notification initialization here.
  //
  // TaskNotificationService initializes lazily when a reminder
  // is created or changed. That prevents native notification/
  // timezone setup from blocking app startup.
  // ---------------------------------------------------------

  final taskNotificationService =
      TaskNotificationService();

  // ---------------------------------------------------------
  // PROVIDERS WITH STORED DATA
  // ---------------------------------------------------------

  final taskProvider = TaskProvider(
    storageService: taskStorageService,
    notificationService:
        taskNotificationService,
    occurrenceCompletionStorage:
        occurrenceCompletionStorage,
  );

  await taskProvider.loadStoredTasks();

  final focusProvider = FocusProvider(
    storageService:
        focusSessionStorageService,
  );

  await focusProvider.loadStoredSessions();

  // ---------------------------------------------------------
  // START APP
  // ---------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => UsageProvider(),
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
}

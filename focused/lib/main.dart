import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/focus_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'services/task_notification_service.dart';
import 'services/task_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------
  // LOCAL STORAGE
  // ---------------------------------------------------------

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();

  await taskStorageService.init();

  // ---------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------
  //
  // IMPORTANT:
  // Do NOT await notification initialization here.
  //
  // TaskNotificationService will initialize itself lazily
  // when a reminder is actually created or changed.
  //
  // This prevents timezone/native notification setup from
  // blocking the entire app startup.
  // ---------------------------------------------------------

  final taskNotificationService = TaskNotificationService();

  // ---------------------------------------------------------
  // TASK PROVIDER
  // ---------------------------------------------------------

  final taskProvider = TaskProvider(
    storageService: taskStorageService,
    notificationService: taskNotificationService,
  );

  await taskProvider.loadStoredTasks();

  // ---------------------------------------------------------
  // START APP
  // ---------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        ChangeNotifierProvider(create: (_) => UsageProvider()..loadMockData()),

        ChangeNotifierProvider(create: (_) => FocusProvider()),

        ChangeNotifierProvider.value(value: taskProvider),
      ],
      child: const FocusProductivityApp(),
    ),
  );
}

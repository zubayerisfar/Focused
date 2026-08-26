import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'app.dart';

import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';

import 'providers/focus_provider.dart';

import 'providers/task_provider.dart';
import 'services/task_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();

  await taskStorageService.init();
  final taskProvider = TaskProvider(storageService: taskStorageService);

  await taskProvider.loadStoredTasks();
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

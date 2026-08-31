import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/account_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/private_sync_provider.dart';
import 'providers/streak_goal_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'providers/user_profile_provider.dart';
import 'router/app_router.dart';
import 'services/android_usage_stats_service.dart';
import 'services/app_category_storage_service.dart';
import 'services/app_metadata_platform_service.dart';
import 'services/app_metadata_storage_service.dart';
import 'services/auth_service.dart';
import 'services/focus_analysis_storage_service.dart';
import 'services/focus_guard_platform_service.dart';
import 'services/focus_session_storage_service.dart';
import 'services/habit_notification_service.dart';
import 'services/habit_storage_service.dart';
import 'services/onboarding_storage_service.dart';
import 'services/private_sync_cloud_service.dart';
import 'services/private_sync_crypto_service.dart';
import 'services/private_sync_secure_storage_service.dart';
import 'services/private_sync_snapshot_service.dart';
import 'services/streak_goal_storage_service.dart';
import 'services/task_notification_service.dart';
import 'services/task_occurrence_completion_storage_service.dart';
import 'services/task_storage_service.dart';
import 'services/usage_record_storage_service.dart';
import 'services/user_profile_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  final taskStorageService = TaskStorageService();
  final occurrenceCompletionStorage =
      TaskOccurrenceCompletionStorageService();
  final focusSessionStorageService =
      FocusSessionStorageService();
  final focusAnalysisStorageService =
      FocusAnalysisStorageService();
  final usageRecordStorageService =
      UsageRecordStorageService();
  final appCategoryStorageService =
      AppCategoryStorageService();
  final appMetadataStorageService =
      AppMetadataStorageService();
  final habitStorageService = HabitStorageService();
  final userProfileStorageService =
      UserProfileStorageService();
  final onboardingStorageService =
      OnboardingStorageService();
  final streakGoalStorageService =
      StreakGoalStorageService();

  await taskStorageService.init();
  await occurrenceCompletionStorage.init();
  await focusSessionStorageService.init();
  await focusAnalysisStorageService.init();
  await usageRecordStorageService.init();
  await appCategoryStorageService.init();
  await appMetadataStorageService.init();
  await habitStorageService.init();
  await userProfileStorageService.init();
  await onboardingStorageService.init();
  await streakGoalStorageService.init();

  final taskNotificationService =
      TaskNotificationService();
  final habitNotificationService =
      HabitNotificationService();
  final focusGuardService =
      FocusGuardPlatformService();

  final taskProvider = TaskProvider(
    storageService: taskStorageService,
    notificationService: taskNotificationService,
    occurrenceCompletionStorage:
        occurrenceCompletionStorage,
  );
  await taskProvider.loadStoredTasks();

  final focusProvider = FocusProvider(
    storageService: focusSessionStorageService,
    focusGuardController: focusGuardService,
    onSessionFinished: (session) async {
      final taskId = session.taskId;
      if (taskId == null) {
        return;
      }

      final task = taskProvider.getTaskById(taskId);
      if (task == null) {
        return;
      }

      final occurrenceDate =
          session.linkedOccurrenceDate ?? session.startedAt;

      if (taskProvider.isTaskCompletedForDate(
        task,
        occurrenceDate,
      )) {
        return;
      }

      await taskProvider.setCompletedForDate(
        taskId,
        occurrenceDate,
        true,
        completedAt: session.endedAt,
      );
    },
  );
  await focusProvider.loadStoredSessions();

  final appMetadataPlatformService =
      AndroidAppMetadataService();

  final usageProvider = UsageProvider(
    usageStatsService: AndroidUsageStatsService(),
    storageService: usageRecordStorageService,
    categoryStorageService:
        appCategoryStorageService,
    focusAnalysisStorageService:
        focusAnalysisStorageService,
    appMetadataService:
        appMetadataPlatformService,
    appMetadataStorageService:
        appMetadataStorageService,
    focusGuardController: focusGuardService,
  );

  await usageProvider.loadStoredCategories();
  await usageProvider
      .syncFocusGuardAllowedPackages();
  await usageProvider.loadStoredFocusAnalyses();
  await usageProvider.loadStoredAppMetadata();
  await usageProvider.loadStoredUsage();

  final habitProvider = HabitProvider(
    storageService: habitStorageService,
    reminderScheduler: habitNotificationService,
  );
  await habitProvider.loadStoredHabits();

  final userProfileProvider =
      UserProfileProvider(
    storageService: userProfileStorageService,
  );
  await userProfileProvider.loadStoredProfile();

  final onboardingProvider =
      OnboardingProvider(
    storageService: onboardingStorageService,
  );
  await onboardingProvider.load();

  final streakGoalProvider =
      StreakGoalProvider(
    storageService: streakGoalStorageService,
  );
  await streakGoalProvider.load();

  final accountProvider = AccountProvider(
    authService: AuthService(),
  );
  await accountProvider.initialize();

  if (accountProvider.isSignedIn) {
    await userProfileProvider.updateProfile(
      displayName: accountProvider.displayName,
      email: accountProvider.email,
    );
  }

  final privateSyncCryptoService =
      PrivateSyncCryptoService();

  final privateSyncSnapshotService =
      PrivateSyncSnapshotService(
    taskStorageService: taskStorageService,
    occurrenceCompletionStorage:
        occurrenceCompletionStorage,
    focusSessionStorageService:
        focusSessionStorageService,
    habitStorageService: habitStorageService,
    userProfileStorageService:
        userProfileStorageService,
    appCategoryStorageService:
        appCategoryStorageService,
    focusAnalysisStorageService:
        focusAnalysisStorageService,
    streakGoalStorageService:
        streakGoalStorageService,
    cryptoService: privateSyncCryptoService,
  );

  final privateSyncProvider =
      PrivateSyncProvider(
    accountProvider: accountProvider,
    cryptoService: privateSyncCryptoService,
    secureStorageService:
        PrivateSyncSecureStorageService(),
    cloudService: PrivateSyncCloudService(),
    snapshotService:
        privateSyncSnapshotService,
    localChangeSources: [
      taskProvider,
      focusProvider,
      habitProvider,
      userProfileProvider,
      streakGoalProvider,
      usageProvider,
    ],
  );
  await privateSyncProvider.initialize();

  final router = createAppRouter(
    accountProvider: accountProvider,
    onboardingProvider: onboardingProvider,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider.value(
          value: accountProvider,
        ),
        ChangeNotifierProvider.value(
          value: onboardingProvider,
        ),
        ChangeNotifierProvider.value(
          value: streakGoalProvider,
        ),
        ChangeNotifierProvider.value(
          value: privateSyncProvider,
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
        ChangeNotifierProvider.value(
          value: habitProvider,
        ),
        ChangeNotifierProvider.value(
          value: userProfileProvider,
        ),
      ],
      child: FocusProductivityApp(
        routerConfig: router,
      ),
    ),
  );

  unawaited(
    usageProvider.refreshPermissionAndUsage(),
  );
}

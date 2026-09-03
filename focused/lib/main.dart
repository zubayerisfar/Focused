import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/account_provider.dart';
import 'providers/app_limit_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/cloud_sync_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/task_mate_provider.dart';
import 'providers/streak_goal_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/user_stats_provider.dart';
import 'router/app_router.dart';
import 'services/account_lifecycle_service.dart';
import 'services/friends_service.dart';
import 'services/task_mate_service.dart';
import 'services/android_installation_info_service.dart';
import 'services/android_usage_stats_service.dart';
import 'services/app_category_storage_service.dart';
import 'services/app_limit_storage_service.dart';
import 'services/app_metadata_platform_service.dart';
import 'services/app_metadata_storage_service.dart';
import 'services/auth_service.dart';
import 'services/focus_analysis_storage_service.dart';
import 'services/focus_guard_platform_service.dart';
import 'services/focus_session_storage_service.dart';
import 'services/habit_notification_service.dart';
import 'services/habit_storage_service.dart';
import 'services/onboarding_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/sync_metadata_storage_service.dart';
import 'services/streak_goal_storage_service.dart';
import 'services/app_usage_summary_service.dart';
import 'services/ad_service.dart';
import 'services/task_notification_service.dart';
import 'services/task_occurrence_completion_storage_service.dart';
import 'services/task_storage_service.dart';
import 'services/usage_record_storage_service.dart';
import 'services/user_cloud_stats_storage_service.dart';
import 'services/user_profile_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  final taskStorageService = TaskStorageService();
  final occurrenceCompletionStorage = TaskOccurrenceCompletionStorageService();
  final focusSessionStorageService = FocusSessionStorageService();
  final focusAnalysisStorageService = FocusAnalysisStorageService();
  final usageRecordStorageService = UsageRecordStorageService();
  final appCategoryStorageService = AppCategoryStorageService();
  final appMetadataStorageService = AppMetadataStorageService();
  final appLimitStorageService = AppLimitStorageService();
  final habitStorageService = HabitStorageService();
  final userProfileStorageService = UserProfileStorageService();
  final onboardingStorageService = OnboardingStorageService();
  final streakGoalStorageService = StreakGoalStorageService();
  final syncMetadataStorageService = SyncMetadataStorageService();
  final userStatsStorageService = UserCloudStatsStorageService();

  await taskStorageService.init();
  await occurrenceCompletionStorage.init();
  await focusSessionStorageService.init();
  await focusAnalysisStorageService.init();
  await usageRecordStorageService.init();
  await appCategoryStorageService.init();
  await appMetadataStorageService.init();
  await appLimitStorageService.init();
  await habitStorageService.init();
  await userProfileStorageService.init();
  await onboardingStorageService.init();
  await streakGoalStorageService.init();
  await syncMetadataStorageService.init();
  await userStatsStorageService.init();

  final installationInfoService = AndroidInstallationInfoService();
  final androidFirstInstallTime = await installationInfoService
      .firstInstallTime();
  final usageHistoryStartedAt = await syncMetadataStorageService
      .getOrCreateUsageTrackingStartedAt(
        installationStartedAt: androidFirstInstallTime,
      );

  final taskNotificationService = TaskNotificationService();
  final habitNotificationService = HabitNotificationService();
  final focusGuardService = FocusGuardPlatformService();

  final taskProvider = TaskProvider(
    storageService: taskStorageService,
    notificationService: taskNotificationService,
    occurrenceCompletionStorage: occurrenceCompletionStorage,
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

      final occurrenceDate = session.linkedOccurrenceDate ?? session.startedAt;

      if (taskProvider.isTaskCompletedForDate(task, occurrenceDate)) {
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

  final appMetadataPlatformService = AndroidAppMetadataService();

  final usageProvider = UsageProvider(
    usageStatsService: AndroidUsageStatsService(),
    storageService: usageRecordStorageService,
    categoryStorageService: appCategoryStorageService,
    focusAnalysisStorageService: focusAnalysisStorageService,
    appMetadataService: appMetadataPlatformService,
    appMetadataStorageService: appMetadataStorageService,
    focusGuardController: focusGuardService,
    historyStartedAt: usageHistoryStartedAt,
  );

  final appLimitProvider = AppLimitProvider(
    storageService: appLimitStorageService,
  );
  await appLimitProvider.loadStoredLimits();

  usageProvider.onUsageUpdated = (usageMap) {
    unawaited(appLimitProvider.checkUsageLimits(usageMap));
  };

  await usageProvider.loadStoredCategories();
  await usageProvider.syncFocusGuardAllowedPackages();
  await usageProvider.loadStoredFocusAnalyses();
  await usageProvider.loadStoredAppMetadata();
  await usageProvider.loadStoredUsage();

  final habitProvider = HabitProvider(
    storageService: habitStorageService,
    reminderScheduler: habitNotificationService,
  );
  await habitProvider.loadStoredHabits();

  final userProfileProvider = UserProfileProvider(
    storageService: userProfileStorageService,
    notificationService: taskNotificationService,
  );
  await userProfileProvider.loadStoredProfile();

  final onboardingProvider = OnboardingProvider(
    storageService: onboardingStorageService,
  );
  await onboardingProvider.load();

  final streakGoalProvider = StreakGoalProvider(
    storageService: streakGoalStorageService,
  );
  await streakGoalProvider.load();

  final userStatsProvider = UserStatsProvider(
    storageService: userStatsStorageService,
  );
  await userStatsProvider.load();

  final accountLifecycleService = AccountLifecycleService(
    taskStorage: taskStorageService,
    taskCompletionStorage: occurrenceCompletionStorage,
    habitStorage: habitStorageService,
    focusSessionStorage: focusSessionStorageService,
    focusAnalysisStorage: focusAnalysisStorageService,
    userProfileStorage: userProfileStorageService,
    streakGoalStorage: streakGoalStorageService,
    syncMetadataStorage: syncMetadataStorageService,
    userStatsStorage: userStatsStorageService,
    usageRecordStorage: usageRecordStorageService,
  );

  late final AccountProvider accountProvider;
  accountProvider = AccountProvider(
    authService: AuthService(),
    lifecycleService: accountLifecycleService,
    onSignOutOrAccountWiped: () async {
      await taskNotificationService.cancelAllTaskReminders();
      await habitNotificationService.cancelAllHabitReminders();
      await accountLifecycleService.clearLocalWorkspaceData();
      await taskProvider.loadStoredTasks();
      await focusProvider.loadStoredSessions();
      await habitProvider.loadStoredHabits();
      await userProfileProvider.resetProfile();
      await streakGoalProvider.load();
      await userStatsProvider.load();
    },
  );
  await accountProvider.initialize();

  if (accountProvider.isSignedIn) {
    await userProfileProvider.updateProfile(
      displayName: accountProvider.displayName,
      email: accountProvider.email,
    );
  }

  final cloudSyncService = CloudSyncService(
    metadataStorage: syncMetadataStorageService,
    taskStorage: taskStorageService,
    taskCompletionStorage: occurrenceCompletionStorage,
    habitStorage: habitStorageService,
    focusSessionStorage: focusSessionStorageService,
    userProfileStorage: userProfileStorageService,
    streakGoalStorage: streakGoalStorageService,
    userStatsStorage: userStatsStorageService,
    usageRecordStorage: usageRecordStorageService,
    themeProvider: themeProvider,
  );

  final cloudSyncProvider = CloudSyncProvider(
    accountProvider: accountProvider,
    syncService: cloudSyncService,
    metadataStorage: syncMetadataStorageService,
    refreshLocalProviders: () async {
      await taskProvider.loadStoredTasks();
      await focusProvider.loadStoredSessions();
      await habitProvider.loadStoredHabits();
      await userProfileProvider.loadStoredProfile();
      await streakGoalProvider.load();
      await userStatsProvider.load();
    },
  );
  await cloudSyncProvider.initialize();

  final router = createAppRouter(
    accountProvider: accountProvider,
    onboardingProvider: onboardingProvider,
  );

  final friendsService = FriendsService();
  final friendsProvider = FriendsProvider(
    friendsService: friendsService,
    profileProvider: userProfileProvider,
    statsProvider: userStatsProvider,
    notificationService: taskNotificationService,
  );
  final taskMateService = TaskMateService();
  final taskMateProvider = TaskMateProvider(
    service: taskMateService,
    notificationService: taskNotificationService,
    statsProvider: userStatsProvider,
    profileProvider: userProfileProvider,
  );
  if (accountProvider.isSignedIn) {
    friendsProvider.initForUser(
      accountProvider.user!.uid,
      displayName: accountProvider.displayName,
      photoUrl: accountProvider.photoUrl,
    );
    taskMateProvider.initForUser(accountProvider.user!.uid);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: onboardingProvider),
        ChangeNotifierProvider.value(value: streakGoalProvider),
        ChangeNotifierProvider.value(value: cloudSyncProvider),
        ChangeNotifierProvider.value(value: appLimitProvider),
        ChangeNotifierProvider.value(value: userStatsProvider),
        ChangeNotifierProvider.value(value: usageProvider),
        ChangeNotifierProvider.value(value: focusProvider),
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider.value(value: habitProvider),
        ChangeNotifierProvider.value(value: userProfileProvider),
        ChangeNotifierProvider.value(value: friendsProvider),
        ChangeNotifierProvider.value(value: taskMateProvider),
      ],
      child: FocusProductivityApp(routerConfig: router),
    ),
  );

  unawaited(usageProvider.refreshPermissionAndUsage());
  unawaited(const AppUsageSummaryService().initialize());
  unawaited(AdService.instance.initialize());
}

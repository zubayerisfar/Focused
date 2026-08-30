import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FocusProductivityApp extends StatefulWidget {
  const FocusProductivityApp({super.key});

  @override
  State<FocusProductivityApp> createState() => _FocusProductivityAppState();
}

class _FocusProductivityAppState extends State<FocusProductivityApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    // This is especially important after the user returns from Android's
    // Usage Access settings, and also keeps today's real usage fresh whenever
    // Focused comes back to the foreground.
    unawaited(
      context.read<UsageProvider>().refreshPermissionAndUsage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Focused',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeProvider.themeMode,
      routerConfig: appRouter,
    );
  }
}

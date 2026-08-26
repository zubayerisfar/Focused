import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';

import 'providers/theme_provider.dart';
import 'providers/usage_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        ChangeNotifierProvider(create: (_) => UsageProvider()..loadMockData()),
      ],
      child: const FocusProductivityApp(),
    ),
  );
}

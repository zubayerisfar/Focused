import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'dark_theme.dart';
import 'light_theme.dart';

export 'app_colors.dart';
export 'app_text_theme.dart';
export 'dark_theme.dart';
export 'light_theme.dart';

/// Central theme orchestrator for the Focused app.
///
/// Modular structure:
/// - [AppColors]: Palettes, surfaces, and semantic colors.
/// - [AppTextTheme]: Quicksand typography scale and text styling.
/// - [buildLightTheme]: Complete Material 3 light theme configuration.
/// - [buildDarkTheme]: Complete Material 3 dark theme configuration.
class AppTheme {
  // Brand & Semantic Palette forwarders for 100% backwards compatibility
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color lavender = AppColors.lavender;
  static const Color mist = AppColors.mist;

  /// Builds the Material 3 Light Theme.
  static ThemeData lightTheme() => buildLightTheme();

  /// Builds the Material 3 Dark Theme.
  static ThemeData darkTheme() => buildDarkTheme();
}

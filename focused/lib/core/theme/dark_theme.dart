import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

ThemeData buildDarkTheme() {
  const scaffold = AppColors.darkScaffold;
  const surface = AppColors.darkSurface;
  const text = AppColors.darkText;
  const muted = AppColors.darkMuted;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.darkPrimary,
        onPrimary: const Color(0xFF0D1424),
        primaryContainer: const Color(0xFF24324A),
        onPrimaryContainer: const Color(0xFFDCE8FF),
        secondary: const Color(0xFF83B5C9),
        secondaryContainer: const Color(0xFF1E3038),
        tertiary: const Color(0xFFC9A978),
        surface: surface,
        surfaceContainerLowest: const Color(0xFF050608),
        surfaceContainerLow: const Color(0xFF0E1117),
        surfaceContainer: surface,
        surfaceContainerHigh: const Color(0xFF1C2230),
        surfaceContainerHighest: const Color(0xFF242A3B),
        onSurface: text,
        onSurfaceVariant: muted,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
        error: AppColors.darkError,
        errorContainer: const Color(0xFF3B1720),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTextTheme.fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    canvasColor: scaffold,
    cardColor: surface,
    dividerColor: AppColors.darkDivider,
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: scaffold,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.transparent,
      indicatorColor: const Color(0xFF6366F1),
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: AppTextTheme.fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          );
        }
        return const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 22);
        }
        return const IconThemeData(color: muted, size: 22);
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: Color(0xFF8EA1BD),
      ),
      hintStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: Color(0xFF5E708A),
      ),
      prefixIconColor: const Color(0xFF7187A7),
      suffixIconColor: const Color(0xFF7187A7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1F2533)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.darkPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.darkError),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: const Color(0xFF0D1424),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        foregroundColor: const Color(0xFFE8EEF8),
        side: const BorderSide(color: Color(0xFF333D50)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        foregroundColor: const Color(0xFF8FB0FF),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primaryContainer,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: AppTextTheme.textTheme(text, muted),
  );
}

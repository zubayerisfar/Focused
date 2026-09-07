import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

ThemeData buildLightTheme() {
  const scaffold = AppColors.lightScaffold;
  const surface = AppColors.lightSurface;
  const surfaceSoft = AppColors.lightSurfaceSoft;
  const text = AppColors.lightText;
  const muted = AppColors.lightMuted;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE8EAF5),
        onPrimaryContainer: const Color(0xFF343B59),
        secondary: AppColors.mist,
        secondaryContainer: const Color(0xFFE7EFEC),
        tertiary: AppColors.warning,
        surface: surface,
        surfaceContainerLowest: surface,
        surfaceContainerLow: const Color(0xFFFAF9F6),
        surfaceContainer: const Color(0xFFF5F4F0),
        surfaceContainerHigh: surfaceSoft,
        surfaceContainerHighest: const Color(0xFFECEBE5),
        onSurface: text,
        onSurfaceVariant: muted,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
        error: AppColors.danger,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppTextTheme.fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    dividerColor: AppColors.lightDivider,
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: scaffold,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: surface,
      indicatorColor: const Color(0xFFE8EAF5),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontFamily: AppTextTheme.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryBlue,
          );
        }
        return const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primaryBlue, size: 24);
        }
        return const IconThemeData(color: muted, size: 24);
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Color(0xFF7B7D84),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(textColor: text, iconColor: muted),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: muted,
      ),
      hintStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: Color(0xFF8A8D95),
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE7E4DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: const BorderSide(color: Color(0xFFDCD8CF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: AppTextTheme.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
      checkmarkColor: text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: text,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        color: text,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: AppTextTheme.textTheme(text, muted),
  );
}

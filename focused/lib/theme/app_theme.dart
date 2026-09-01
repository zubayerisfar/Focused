import 'package:flutter/material.dart';

class AppTheme {
  // A deliberately softer palette than the earlier bright-blue treatment.
  // The colors stay distinct enough for priority/status communication while
  // keeping the day-to-day interface calm.
  static const Color primaryBlue = Color(0xFF7584B8);
  static const Color success = Color(0xFF789F8C);
  static const Color warning = Color(0xFFC79D6B);
  static const Color danger = Color(0xFFC77E7E);
  static const Color lavender = Color(0xFF9A8FB8);
  static const Color mist = Color(0xFF8FA7A2);

  static ThemeData lightTheme() {
    const scaffold = Color(0xFFF7F6F2);
    const surface = Color(0xFFFFFEFB);
    const surfaceSoft = Color(0xFFF1F0EB);
    const text = Color(0xFF292B31);
    const muted = Color(0xFF6F727A);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryBlue,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE8EAF5),
          onPrimaryContainer: const Color(0xFF343B59),
          secondary: mist,
          secondaryContainer: const Color(0xFFE7EFEC),
          tertiary: warning,
          surface: surface,
          surfaceContainerLowest: surface,
          surfaceContainerLow: const Color(0xFFFAF9F6),
          surfaceContainer: const Color(0xFFF5F4F0),
          surfaceContainerHigh: surfaceSoft,
          surfaceContainerHighest: const Color(0xFFECEBE5),
          onSurface: text,
          onSurfaceVariant: muted,
          outline: const Color(0xFFCAC8C0),
          outlineVariant: const Color(0xFFE4E1D9),
          error: danger,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Quicksand',
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: const Color(0xFFE7E4DC),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor: const Color(0xFFE8EAF5),
        elevation: 0,
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
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: Color(0xFF8A8D95)),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          borderSide: const BorderSide(color: primaryBlue, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: Color(0xFFDCD8CF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh.withOpacity(0.55),
        checkmarkColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    const scaffold = Color(0xFF050914);
    const surface = Color(0xFF0B1423);
    const text = Color(0xFFF3F7FF);
    const muted = Color(0xFF91A2BB);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F9AFF),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF7EA2FF),
          onPrimary: const Color(0xFF06101F),
          primaryContainer: const Color(0xFF152641),
          onPrimaryContainer: const Color(0xFFDCE8FF),
          secondary: const Color(0xFF83B5C9),
          secondaryContainer: const Color(0xFF12313E),
          tertiary: const Color(0xFFC9A978),
          surface: surface,
          surfaceContainerLowest: const Color(0xFF060B13),
          surfaceContainerLow: const Color(0xFF09111E),
          surfaceContainer: const Color(0xFF0D1727),
          surfaceContainerHigh: const Color(0xFF111D30),
          surfaceContainerHighest: const Color(0xFF16243A),
          onSurface: text,
          onSurfaceVariant: muted,
          outline: const Color(0xFF42516A),
          outlineVariant: const Color(0xFF1D2B40),
          error: const Color(0xFFFF9DAF),
          errorContainer: const Color(0xFF3B1720),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Quicksand',
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      dividerColor: const Color(0xFF1A2940),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFF08111D),
        indicatorColor: Color(0xFF152641),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0B1423),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF0D1727),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A1321),
        labelStyle: const TextStyle(color: Color(0xFF8EA1BD)),
        hintStyle: const TextStyle(color: Color(0xFF5E708A)),
        prefixIconColor: const Color(0xFF7187A7),
        suffixIconColor: const Color(0xFF7187A7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF1E304A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF6F9AFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF9DAF)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: const Color(0xFF6F9AFF),
          foregroundColor: const Color(0xFF06101F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          foregroundColor: const Color(0xFFE8EEF8),
          side: const BorderSide(color: Color(0xFF243955)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF8FB0FF),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
      ),
    );
  }
}

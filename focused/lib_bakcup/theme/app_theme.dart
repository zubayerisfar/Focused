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

    final scheme = ColorScheme.fromSeed(
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
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
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    const scaffold = Color(0xFF151619);
    const surface = Color(0xFF1D1F23);
    const text = Color(0xFFF2F0EA);
    const muted = Color(0xFFAFB0B5);

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFA9B4DE),
      primaryContainer: const Color(0xFF34394D),
      secondary: const Color(0xFFA6B9B4),
      secondaryContainer: const Color(0xFF2A3734),
      tertiary: const Color(0xFFD4B287),
      surface: surface,
      surfaceContainerLowest: const Color(0xFF18191C),
      surfaceContainerLow: const Color(0xFF1B1D20),
      surfaceContainer: const Color(0xFF222428),
      surfaceContainerHigh: const Color(0xFF272A2F),
      surfaceContainerHighest: const Color(0xFF2D3036),
      onSurface: text,
      onSurfaceVariant: muted,
      outline: const Color(0xFF5E6067),
      outlineVariant: const Color(0xFF34363C),
      error: const Color(0xFFD99A9A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      dividerColor: const Color(0xFF303238),
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
        backgroundColor: const Color(0xFF1A1C20),
        indicatorColor: const Color(0xFF34394D),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202226),
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
          borderSide: const BorderSide(color: Color(0xFF303238)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFA9B4DE),
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
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
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static TextTheme _buildTextTheme(Color textColor, [bool isDark = false]) {
    return TextTheme(
      displayLarge: GoogleFonts.urbanist(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.urbanist(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.urbanist(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
        height: 1.22,
      ),
      headlineLarge: GoogleFonts.urbanist(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
        height: 1.15,
      ),
      headlineMedium: GoogleFonts.urbanist(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
      headlineSmall: GoogleFonts.urbanist(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.urbanist(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
      titleMedium: GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
        height: 1.35,
      ),
      bodyLarge: GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
        height: 1.35,
      ),
      bodyMedium: GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
        height: 1.35,
      ),
      bodySmall: GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
        height: 1.25,
      ),
      labelLarge: GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
      labelMedium: GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
      labelSmall: GoogleFonts.urbanist(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textColor,
        height: 1.2,
      ),
    );
  }

  static const SystemUiOverlayStyle overlayLightTheme = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bgSecondary,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: true,
  );

  static const SystemUiOverlayStyle overlayDarkTheme = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.darkBgPrimary,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: true,
  );

  static ThemeData light() {
    final textTheme = _buildTextTheme(AppColors.textPrimary);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accentGreen,
      tertiary: AppColors.primaryEmerald,
      surface: AppColors.surfaceLight,
      background: AppColors.bgPrimary,
      error: AppColors.statusError,
      onPrimary: AppColors.textWhite,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      textTheme: textTheme,
      dividerColor: AppColors.borderLight,
      hintColor: AppColors.textTertiary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: overlayLightTheme,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.statusError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.statusError, width: 1.8),
        ),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle:
            textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelSmall,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle:
            textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
        subtitleTextStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  static ThemeData dark() {
    final textTheme = _buildTextTheme(AppColors.darkTextPrimary, true);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryGreen,
      secondary: AppColors.primaryEmerald,
      tertiary: AppColors.statusWarningDark,
      surface: AppColors.surfaceDark,
      background: AppColors.darkBgPrimary,
      error: AppColors.statusError,
      onPrimary: Colors.black,
      onSurface: AppColors.darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBgPrimary,
      textTheme: textTheme,
      dividerColor: AppColors.darkBorderLight,
      hintColor: AppColors.darkTextTertiary,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: overlayDarkTheme,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.darkBorderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.darkBorderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.statusError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.statusError, width: 1.8),
        ),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
        hintStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.darkTextTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.black),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryEmerald,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primaryEmerald, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle:
              textTheme.labelLarge?.copyWith(color: AppColors.primaryEmerald),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryEmerald,
          textStyle:
              textTheme.labelLarge?.copyWith(color: AppColors.primaryEmerald),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorderLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle:
            textTheme.bodyLarge?.copyWith(color: AppColors.darkTextPrimary),
        subtitleTextStyle:
            textTheme.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
      ),
    );
  }

  static Color getAdaptiveColor(
    BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    return Theme.of(context).brightness == Brightness.light
        ? lightColor
        : darkColor;
  }

  static Color getAdaptiveTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.textPrimary
        : AppColors.darkTextPrimary;
  }

  static Color getAdaptiveSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.surfaceLight
        : AppColors.surfaceDark;
  }
}

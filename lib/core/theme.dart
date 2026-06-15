import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette extracted from the Afrahna logo:
/// warm cream background with rose-gold / copper accents.
class AppColors {
  // Brand — rose gold / copper from the logo script
  static const Color primary = Color(0xFFB8835A);
  static const Color primaryDark = Color(0xFF8B5A3C);
  static const Color primaryLight = Color(0xFFF0DDC8);
  static const Color accent = Color(0xFFD4A373);

  // Backgrounds — cream / ivory like the logo plate
  static const Color background = Color(0xFFFAF3EC);
  static const Color surface = Color(0xFFFFFBF6);

  // Text — deep coffee for warmth (instead of pure black)
  static const Color textDark = Color(0xFF3D2817);
  static const Color textMuted = Color(0xFF9C8273);

  // Utility
  static const Color discount = Color(0xFFC1452B); // warm terracotta red
  static const Color cardShadow = Color(0x1AB8835A);

  /// Light brand gradient (cream → soft gold).
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFAF3EC), Color(0xFFEBD7BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep brand gradient (mocha → copper) — for hero overlays.
  static const LinearGradient brandDeepGradient = LinearGradient(
    colors: [Color(0xFF3D2817), Color(0xFF6B4226), Color(0xFFB8835A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppAssets {
  static const String logo = 'assets/images/logo.png';
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.tajawalTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ).copyWith(
        secondary: AppColors.accent,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.discount, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.discount, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textDark),
    );
  }
}

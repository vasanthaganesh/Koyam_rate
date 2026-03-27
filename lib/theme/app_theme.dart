import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable colors matching the Stitch design system.
class AppColors {
  AppColors._();

  // Primary brand colors (from Stitch: #ec5b13 orange, #4CAF50 green)
  static const Color primary = Color(0xFFFF9800);
  static const Color primaryLight = Color(0x1AFF9800); // 10% opacity
  static const Color green = Color(0xFF4CAF50);
  static const Color greenLight = Color(0x1A4CAF50);

  // Background
  static const Color backgroundLight = Color(0xFFF8F6F6);
  static const Color backgroundDark = Color(0xFF221610);

  // Surface / Glass
  static const Color glassWhite = Color(0x33FFFFFF); // 20% white
  static const Color glassBorder = Color(0x66FFFFFF); // 40% white
  static const Color glassInnerGlow = Color(0x1AFFFFFF); // 10%

  // Text
  static const Color textPrimary = Color(0xFF1E293B); // slate-800
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color priceUp = Color(0xFFDC2626); // red-600
  static const Color priceDown = Color(0xFF16A34A); // green-600
  static const Color stable = Color(0xFF94A3B8); // slate-400

  // Misc
  static const Color divider = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0x1A000000);
}

/// App-wide theme data.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        surface: AppColors.backgroundLight,
      ),
    );

    return baseTheme.copyWith(
      // Use Hind Madurai for Tamil support + Public Sans/Inter for English
      textTheme: GoogleFonts.hindMaduraiTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.publicSans(textStyle: baseTheme.textTheme.displayLarge),
        displayMedium: GoogleFonts.publicSans(textStyle: baseTheme.textTheme.displayMedium),
        bodyLarge: GoogleFonts.publicSans(textStyle: baseTheme.textTheme.bodyLarge),
        bodyMedium: GoogleFonts.publicSans(textStyle: baseTheme.textTheme.bodyMedium),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.publicSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.publicSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: GoogleFonts.publicSans(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Glass effect constants – matching Stitch frosted-glass CSS
  static const double glassBlurSigma = 16.0;
  static const double glassOpacity = 0.20;
  static const double glassBorderOpacity = 0.40;
  static const double cardBorderRadius = 28.0;
  static const double cardPadding = 12.0;

  /// Multi-layer shadow for 3D "floating" effect per Stitch cards
  static List<BoxShadow> get card3DShadow => [
        const BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 4),
          blurRadius: 6,
          spreadRadius: -1,
        ),
        const BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 10),
          blurRadius: 15,
          spreadRadius: -3,
        ),
        const BoxShadow(
          color: Color(0x0D000000),
          offset: Offset(0, 20),
          blurRadius: 25,
          spreadRadius: -5,
        ),
      ];
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette - derived from Pencil design
class AppColors {
  // Primary
  static const purple = Color(0xFF8B5CF6);
  static const purpleSoft = Color(0x208B5CF6); // 12.5% opacity

  // Semantic
  static const teal = Color(0xFF14B8A6); // Success, matched
  static const pink = Color(0xFFF472B6); // Accent, hints

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF4F4F5); // Card backgrounds
  static const elevated = Color(0xFFE4E4E7);

  // Text
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF71717A);
  static const textTertiary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFFD4D4D8);
}

/// App typography using Google Fonts
class AppTypography {
  // Headlines - Plus Jakarta Sans
  static TextStyle headline1 = GoogleFonts.plusJakartaSans(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static TextStyle headline2 = GoogleFonts.plusJakartaSans(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static TextStyle headline3 = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Metrics (large numbers)
  static TextStyle metric = GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.purple,
  );

  static TextStyle metricSmall = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  // Body - Inter
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Labels
  static TextStyle label = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  // Buttons
  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static TextStyle buttonSecondary = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

/// App spacing constants
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// App radius constants
class AppRadius {
  static const double card = 16;
  static const double button = 24;
  static const double logo = 32;
  static const double badge = 20;
  static const double circular = 100;
}

/// App theme configuration
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        brightness: Brightness.light,
        primary: AppColors.purple,
        secondary: AppColors.teal,
        tertiary: AppColors.pink,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(),
    );
  }
}

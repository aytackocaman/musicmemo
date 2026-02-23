import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme-varying colors that adapt between light and dark mode.
@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  const AppColorsTheme({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
  });

  final Color background;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  static const light = AppColorsTheme(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F5),
    elevated: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF71717A),
    textTertiary: Color(0xFFA1A1AA),
    textMuted: Color(0xFFD4D4D8),
  );

  static const dark = AppColorsTheme(
    background: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    elevated: Color(0xFF3A3A3C),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0xFFAEAEB2),
    textTertiary: Color(0xFF8E8E93),
    textMuted: Color(0xFF636366),
  );

  @override
  AppColorsTheme copyWith({
    Color? background,
    Color? surface,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
  }) {
    return AppColorsTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColorsTheme lerp(AppColorsTheme? other, double t) {
    if (other is! AppColorsTheme) return this;
    return AppColorsTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Shorthand to access the current theme's AppColorsTheme from any BuildContext.
extension AppColorsContext on BuildContext {
  AppColorsTheme get colors => Theme.of(this).extension<AppColorsTheme>()!;
}

/// App color palette — brand colors only (theme-invariant).
class AppColors {
  // Primary
  static const purple = Color(0xFF8B5CF6);
  static const purpleSoft = Color(0x208B5CF6);

  // Semantic
  static const teal = Color(0xFF14B8A6);
  static const pink = Color(0xFFF472B6);

  // Always-white (for text/icons on colored backgrounds)
  static const white = Color(0xFFFFFFFF);

  // Badge / accent
  static const green = Color(0xFF10B981); // emerald-500
  static const gold = Color(0xFFFBBF24);  // amber-400
}

/// App typography using Google Fonts.
/// Methods that use context-varying colors take [BuildContext].
/// Static fields are used for styles that always use brand colors.
class AppTypography {
  // ── Headlines ──────────────────────────────────────────────────────────────
  static TextStyle headline1(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: context.colors.textPrimary,
      );

  static TextStyle headline2(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: context.colors.textPrimary,
      );

  static TextStyle headline3(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      );

  // ── Metrics ─────────────────────────────────────────────────────────────────
  // Always purple — no context needed
  static final TextStyle metric = GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.purple,
  );

  static TextStyle metricSmall(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: context.colors.textPrimary,
      );

  // ── Body ────────────────────────────────────────────────────────────────────
  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.colors.textPrimary,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: context.colors.textPrimary,
      );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.colors.textSecondary,
      );

  // ── Labels ──────────────────────────────────────────────────────────────────
  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colors.textPrimary,
      );

  static TextStyle labelSmall(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.colors.textTertiary,
      );

  // ── Buttons ─────────────────────────────────────────────────────────────────
  // Always white (on purple buttons) — no context needed
  static final TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static TextStyle buttonSecondary(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: context.colors.textPrimary,
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
      scaffoldBackgroundColor: AppColorsTheme.light.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        brightness: Brightness.light,
        primary: AppColors.purple,
        secondary: AppColors.teal,
        tertiary: AppColors.pink,
        surface: AppColorsTheme.light.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      extensions: [AppColorsTheme.light],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColorsTheme.dark.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        brightness: Brightness.dark,
        primary: AppColors.purple,
        secondary: AppColors.teal,
        tertiary: AppColors.pink,
        surface: AppColorsTheme.dark.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      extensions: [AppColorsTheme.dark],
    );
  }
}

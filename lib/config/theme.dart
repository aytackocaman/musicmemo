import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Accent Color ──────────────────────────────────────────────────────────────

enum AccentColor { blue, purple, red }

@immutable
class AccentColorData {
  final Color primary;
  final Color primarySoft;
  final Color gradientLight;
  final Color gradientDark;

  const AccentColorData({
    required this.primary,
    required this.primarySoft,
    required this.gradientLight,
    required this.gradientDark,
  });

  static const blue = AccentColorData(
    primary: Color(0xFF3B82F6),
    primarySoft: Color(0x203B82F6),
    gradientLight: Color(0xFF60A5FA),
    gradientDark: Color(0xFF2563EB),
  );

  static const purple = AccentColorData(
    primary: Color(0xFF8B5CF6),
    primarySoft: Color(0x208B5CF6),
    gradientLight: Color(0xFF9B6FF7),
    gradientDark: Color(0xFF7C3AED),
  );

  static const red = AccentColorData(
    primary: Color(0xFFEF4444),
    primarySoft: Color(0x20EF4444),
    gradientLight: Color(0xFFF87171),
    gradientDark: Color(0xFFDC2626),
  );

  static AccentColorData fromEnum(AccentColor accent) => switch (accent) {
        AccentColor.blue => blue,
        AccentColor.purple => purple,
        AccentColor.red => red,
      };
}

// ─── Theme Extension ───────────────────────────────────────────────────────────

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
    required this.accent,
    required this.accentSoft,
    required this.accentGradientLight,
    required this.accentGradientDark,
  });

  final Color background;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color accentGradientLight;
  final Color accentGradientDark;

  static AppColorsTheme light({AccentColorData accentData = AccentColorData.blue}) =>
      AppColorsTheme(
        background: const Color(0xFFFFFFFF),
        surface: const Color(0xFFF4F4F5),
        elevated: const Color(0xFFE4E4E7),
        textPrimary: const Color(0xFF18181B),
        textSecondary: const Color(0xFF71717A),
        textTertiary: const Color(0xFFA1A1AA),
        textMuted: const Color(0xFFD4D4D8),
        accent: accentData.primary,
        accentSoft: accentData.primarySoft,
        accentGradientLight: accentData.gradientLight,
        accentGradientDark: accentData.gradientDark,
      );

  static AppColorsTheme dark({AccentColorData accentData = AccentColorData.blue}) =>
      AppColorsTheme(
        background: const Color(0xFF1C1C1E),
        surface: const Color(0xFF2C2C2E),
        elevated: const Color(0xFF3A3A3C),
        textPrimary: const Color(0xFFF2F2F7),
        textSecondary: const Color(0xFFAEAEB2),
        textTertiary: const Color(0xFF8E8E93),
        textMuted: const Color(0xFF636366),
        accent: accentData.primary,
        accentSoft: accentData.primarySoft,
        accentGradientLight: accentData.gradientLight,
        accentGradientDark: accentData.gradientDark,
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
    Color? accent,
    Color? accentSoft,
    Color? accentGradientLight,
    Color? accentGradientDark,
  }) {
    return AppColorsTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentGradientLight: accentGradientLight ?? this.accentGradientLight,
      accentGradientDark: accentGradientDark ?? this.accentGradientDark,
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
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentGradientLight: Color.lerp(accentGradientLight, other.accentGradientLight, t)!,
      accentGradientDark: Color.lerp(accentGradientDark, other.accentGradientDark, t)!,
    );
  }
}

/// Shorthand to access the current theme's AppColorsTheme from any BuildContext.
extension AppColorsContext on BuildContext {
  AppColorsTheme get colors => Theme.of(this).extension<AppColorsTheme>()!;
}

/// Convert a hex color string (e.g. '#8B5CF6') to a [Color].
Color hexToColor(String hex) {
  return Color(int.parse(hex.replaceFirst('#', '0xFF')));
}

/// App color palette — brand colors only (theme-invariant).
class AppColors {
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
  static TextStyle metric(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: context.colors.accent,
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
  static ThemeData lightTheme([AccentColor accent = AccentColor.blue]) {
    final accentData = AccentColorData.fromEnum(accent);
    final colors = AppColorsTheme.light(accentData: accentData);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentData.primary,
        brightness: Brightness.light,
        primary: accentData.primary,
        secondary: AppColors.teal,
        tertiary: AppColors.pink,
        surface: colors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      extensions: [colors],
    );
  }

  static ThemeData darkTheme([AccentColor accent = AccentColor.blue]) {
    final accentData = AccentColorData.fromEnum(accent);
    final colors = AppColorsTheme.dark(accentData: accentData);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentData.primary,
        brightness: Brightness.dark,
        primary: accentData.primary,
        secondary: AppColors.teal,
        tertiary: AppColors.pink,
        surface: colors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      extensions: [colors],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// أحلى طلة — full design token set matching the Stitch mockups the new
/// mobile screens are built against. All colors are exposed as static
/// consts so widgets can reach for `AppTheme.flameDeep` directly, and the
/// Material 3 ColorScheme is derived from them so stock widgets (buttons,
/// switches, chips) inherit the same palette without every widget having
/// to override individually.
///
/// Fonts:
///   - **Space Grotesk** (headlines, price tags, display) via Google Fonts
///   - **Plus Jakarta Sans** (body, labels) via Google Fonts
/// Both load lazily over the network the first time the app renders, then
/// are cached forever. No .ttf shipped in the bundle.
class AppTheme {
  // -------- brand identity --------
  static const Color brand = Color(0xFFE87722);      // logo orange (primary-container)
  static const Color brandDark = Color(0xFF1F1B1A);  // logo bg
  static const Color surface = Color(0xFFFFF8F6);    // Stitch bg

  // -------- Stitch design tokens (verbatim from the new-shape HTML) --------
  static const Color primary = Color(0xFF994700);
  static const Color primaryContainer = Color(0xFFE87722);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF4F2200);
  static const Color primaryFixed = Color(0xFFFFDBC8);
  static const Color primaryFixedDim = Color(0xFFFFB68B);
  static const Color onPrimaryFixed = Color(0xFF321300);
  static const Color onPrimaryFixedVariant = Color(0xFF743400);

  static const Color secondary = Color(0xFF635D5C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFEAE0DE);
  static const Color onSecondaryContainer = Color(0xFF696362);
  static const Color secondaryFixed = Color(0xFFEAE0DE);
  static const Color secondaryFixedDim = Color(0xFFCDC5C3);
  static const Color onSecondaryFixed = Color(0xFF1F1B1A);
  static const Color onSecondaryFixedVariant = Color(0xFF4B4644);

  static const Color tertiary = Color(0xFF855300);
  static const Color tertiaryContainer = Color(0xFFD18500);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF442800);
  static const Color tertiaryFixed = Color(0xFFFFDDB8);
  static const Color tertiaryFixedDim = Color(0xFFFFB95F);
  static const Color onTertiaryFixed = Color(0xFF2A1700);
  static const Color onTertiaryFixedVariant = Color(0xFF653E00);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color surfaceBright = Color(0xFFFFF8F6);
  static const Color surfaceDim = Color(0xFFE2D8D4);
  static const Color surfaceCream = Color(0xFFFDFAF6);
  static const Color surfaceCreamSubtle = Color(0xFFF7F3EE);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFCF1EE);
  static const Color surfaceContainer = Color(0xFFF6ECE8);
  static const Color surfaceContainerHigh = Color(0xFFF0E6E2);
  static const Color surfaceContainerHighest = Color(0xFFEBE0DD);
  static const Color surfaceVariant = Color(0xFFEBE0DD);
  static const Color onSurface = Color(0xFF1F1B19);
  static const Color onSurfaceVariant = Color(0xFF564337);
  static const Color inverseSurface = Color(0xFF352F2D);
  static const Color inverseOnSurface = Color(0xFFF9EFEB);
  static const Color inversePrimary = Color(0xFFFFB68B);

  static const Color outline = Color(0xFF8A7265);
  static const Color outlineVariant = Color(0xFFDDC1B2);

  // Accent tokens the Stitch design leans on heavily
  static const Color flameDeep = Color(0xFFE65100);
  static const Color amberVibrant = Color(0xFFF97316);
  static const Color goldLight = Color(0xFFFDE68A);
  static const Color charcoalSoft = Color(0xFF393230);
  static const Color charcoalMuted = Color(0xFF6E635F);
  static const Color pomegranateRed = Color(0xFFDC2626);
  static const Color herbFresh = Color(0xFF15803D);

  // -------- typography helpers --------
  /// Space Grotesk headline TextStyle — pass size + weight, everything else
  /// (color, letter-spacing) matches the Stitch tokens.
  static TextStyle headline({double size = 20, FontWeight weight = FontWeight.w700, Color? color, double? letterSpacing, double? height}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Plus Jakarta Sans body TextStyle.
  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color, double? letterSpacing, double? height}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Price tag (Space Grotesk 700, tabular-ish spacing).
  static TextStyle priceTag({double size = 18, Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 22 / 18,
      );

  // -------- ThemeData --------
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryContainer,
      onPrimary: onPrimary,
      primaryContainer: primaryFixed,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceBright: surfaceBright,
      surfaceDim: surfaceDim,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      inversePrimary: inversePrimary,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );

    // Base body text uses Plus Jakarta Sans; headline uses Space Grotesk.
    // Text theme is fed by GoogleFonts so it participates in the Material
    // widget defaults (button labels, ListTile titles, etc.).
    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final headlineText = GoogleFonts.spaceGroteskTextTheme();

    final merged = baseText.copyWith(
      displayLarge:   headlineText.displayLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium:  headlineText.displayMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      displaySmall:   headlineText.displaySmall?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      headlineLarge:  headlineText.headlineLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
      headlineMedium: headlineText.headlineMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      headlineSmall:  headlineText.headlineSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleLarge:     headlineText.titleLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleMedium:    baseText.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      titleSmall:     baseText.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      bodyLarge:      baseText.bodyLarge?.copyWith(color: onSurface),
      bodyMedium:     baseText.bodyMedium?.copyWith(color: onSurface),
      bodySmall:      baseText.bodySmall?.copyWith(color: onSurfaceVariant),
      labelLarge:     baseText.labelLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      labelMedium:    baseText.labelMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
      labelSmall:     baseText.labelSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: 0.4),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      textTheme: merged,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceCreamSubtle,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
      ),
      dividerColor: outlineVariant,
    );
  }
}

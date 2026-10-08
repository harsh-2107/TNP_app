import 'package:flutter/material.dart';

/// Centralized color palette for the IIIT Nagpur Placement Cell app.
///
/// Never reference raw [Color] values from widgets — always go through
/// this class (or `context.colors` via [AppColorsExtension]) so a brand
/// refresh only ever touches this one file.
class AppColors {
  const AppColors._();

  // Brand colors from Dribbble Corporate Portal (Electric Royal Blue + Warm Orange)
  static const Color primary = Color(0xFF29335C);
  static const Color primaryDark = Color(0xFFE4E7EB);
  static const Color primaryLight = Color(0xFF94BFBE);

  // Secondary CTA Warm Orange
  static const Color secondary = Color(0xFFFA5A16);
  static const Color accentOrange = Color(0xFFFA5A16);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F5F8);
  static const Color surfaceSuccess = Color(0xFFF0FDF4);
  static const Color surfaceSuccessAlt = Color(0xFFEFF4FF);

  // Shadows
  static const Color shadowLight = Color(0x05000000);
  static const Color shadowDark = Color(0x0F111827);
  static const Color innerHighlight = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFEAEAEC);
  static const Color borderStrong = Color(0xFFDCDFE5);
  static const Color borderSuccess = Color(0xFFBBF7D0);
  static const Color borderSuccessAlt = Color(0xFFD6E4FF);

  // Typography Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF7E8492);
  static const Color textMuted = Color(0xFFA1A7B5);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color onPrimary = Colors.white;

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444);
  static const Color surfaceError = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFFA5A16);
  static const Color info = Color(0xFF1668FE);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1668FE), Color(0xFF0C53DC)],
  );

  // Dark-mode overrides
  static const Color backgroundDark = Color(0xFF0F141C);
  static const Color surfaceDark = Color(0xFF181F2A);
  static const Color shadowLightDark = Color(0x0DFFFFFF);
  static const Color shadowDarkDark = Color(0x2E000000);
  static const Color borderDark = Color(0xFF263040);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
}

import 'package:flutter/material.dart';

/// Centralized color palette for the IIIT Nagpur Placement Cell app.
///
/// Never reference raw [Color] values from widgets — always go through
/// this class (or `context.colors` via [AppColorsExtension]) so a brand
/// refresh only ever touches this one file.
class AppColors {
  const AppColors._();

  // Brand / primary gradient (teal).
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0D9488);
  static const Color primaryLight = Color(0xFF5EEAD4);

  // Secondary / navy, used for the status bar & headline text on light bg.
  static const Color secondary = Color(0xFF1A3A52);

  // Surfaces.
  static const Color background = Color(0xFFE2E8F0); // Darkened significantly to make white highlights pop
  static const Color surface = Color(0xFFFFFFFF); // Cards stay bright white
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceSuccess = Color(0xFFF0FDF4);
  static const Color surfaceSuccessAlt = Color(0xFFECFDF5);

  // 3D Shadows & Highlights (Claymorphic/Neumorphic tokens)
  static const Color shadowLight = Color(0xFFFFFFFF); // Top-left highlight
  static const Color shadowDark = Color(0xFF94A3B8); // Much deeper bottom-right shadow
  static const Color innerHighlight = Color(0xFFFFFFFF); // Inner molding highlight

  // Borders.
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color borderSuccess = Color(0xFFBBF7D0);
  static const Color borderSuccessAlt = Color(0xFFA7F3D0);

  // Text.
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color onPrimary = Colors.white;

  // Semantic.
  static const Color success = Color(0xFF047857);
  static const Color successDark = Color(0xFF065F46);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Dark-mode overrides — extended the same way as the light palette so
  // AppTheme.darkTheme stays a drop-in replacement.
  static const Color backgroundDark = Color(0xFF0F1417);
  static const Color surfaceDark = Color(0xFF161E23); // Slightly brighter than bg
  static const Color shadowLightDark = Color(0x1AFFFFFF); // Soft top-left glow
  static const Color shadowDarkDark = Color(0xFF090D0F); // Deep bottom-right shadow
  static const Color borderDark = Color(0xFF233038);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
}

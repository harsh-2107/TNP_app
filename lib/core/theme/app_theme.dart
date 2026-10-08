import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// A [ThemeExtension] exposing the design-token classes through
/// `Theme.of(context).extension<AppThemeExtension>()` (see
/// `core/extensions/context_extensions.dart` for the `context.colors`
/// sugar). Add a new theme by adding a new static factory here — nothing
/// else in the app needs to change.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.gradient,
    required this.surfaceSuccess,
    required this.borderSuccess,
  });

  final LinearGradient gradient;
  final Color surfaceSuccess;
  final Color borderSuccess;

  static const light = AppThemeExtension(
    gradient: AppColors.primaryGradient,
    surfaceSuccess: AppColors.surfaceSuccess,
    borderSuccess: AppColors.borderSuccess,
  );

  static const dark = AppThemeExtension(
    gradient: AppColors.primaryGradient,
    surfaceSuccess: Color(0xFF12241F),
    borderSuccess: Color(0xFF1F3A32),
  );

  @override
  AppThemeExtension copyWith({
    LinearGradient? gradient,
    Color? surfaceSuccess,
    Color? borderSuccess,
  }) {
    return AppThemeExtension(
      gradient: gradient ?? this.gradient,
      surfaceSuccess: surfaceSuccess ?? this.surfaceSuccess,
      borderSuccess: borderSuccess ?? this.borderSuccess,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// App-wide [ThemeData] factories. `main.dart` / `app.dart` should only
/// ever reference [AppTheme.lightTheme] and [AppTheme.darkTheme] — never
/// build ad-hoc themes inline in a screen.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    );

    return _base(colorScheme, AppColors.background).copyWith(
      extensions: const [AppThemeExtension.light],
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.secondary,
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.secondary,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      error: AppColors.error,
      onError: Colors.white,
    );

    return _base(colorScheme, AppColors.backgroundDark).copyWith(
      extensions: const [AppThemeExtension.dark],
      brightness: Brightness.dark,
    );
  }

  static ThemeData _base(ColorScheme scheme, Color scaffoldBg) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        headlineLarge: AppTypography.h1.copyWith(color: scheme.onSurface),
        headlineMedium: AppTypography.h2.copyWith(color: scheme.onSurface),
        headlineSmall: AppTypography.h3.copyWith(color: scheme.onSurface),
        titleMedium: AppTypography.titleMedium.copyWith(color: scheme.onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: scheme.onSurface),
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.button,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleMedium.copyWith(color: scheme.onPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        labelStyle: AppTypography.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTypography.button,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        behavior: SnackBarBehavior.floating,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

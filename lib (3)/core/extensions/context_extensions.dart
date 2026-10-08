import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Convenience getters on [BuildContext].
///
/// Design tokens ([AppColors], [AppSpacing], [AppTypography], [AppRadius])
/// are static classes, so call sites simply write `AppColors.primary`,
/// `AppSpacing.md`, etc. directly — no context needed. This extension is
/// reserved for the handful of things that genuinely depend on the
/// current [BuildContext] (theme mode, screen size, showing a snackbar).
extension BuildContextX on BuildContext {
  /// Theme-reactive tokens (differ between light/dark). Prefer this over
  /// [AppColors] when a value must adapt to dark mode.
  AppThemeExtension get appTheme =>
      Theme.of(this).extension<AppThemeExtension>() ?? AppThemeExtension.light;

  ThemeData get theme => Theme.of(this);

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isTablet => screenSize.shortestSide >= 600;

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, tertiary, outline, text, google }

/// Single button component covering every button style in the design
/// (gradient "Sign In", outlined "View Details", the Google button, …).
/// Screens configure it through parameters instead of hand-rolling
/// [Container] + [InkWell] each time.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.isSmall = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isSmall;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final child = _buildContent(context);
    final button = switch (variant) {
      AppButtonVariant.primary => _GradientButton(
        onPressed: _isDisabled ? null : onPressed,
        isSmall: isSmall,
        child: child,
      ),
      AppButtonVariant.secondary => ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.secondary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isSmall ? 8 : 14,
            horizontal: 24,
          ),
        ),
        child: child,
      ),
      AppButtonVariant.outline || AppButtonVariant.google => OutlinedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isSmall ? 8 : 14,
            horizontal: 24,
          ),
          backgroundColor: variant == AppButtonVariant.google
              ? Colors.white
              : Colors.transparent,
          foregroundColor: AppColors.textPrimary,
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: _isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.tertiary => ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.primaryLight.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isSmall ? 8 : 14,
            horizontal: 24,
          ),
        ),
        child: child,
      ),
    };

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.outline ||
                    variant == AppButtonVariant.google
                ? AppColors.primary
                : Colors.white,
          ),
        ),
      );
    }

    if (icon == null) {
      return Text(
        label,
        style: AppTypography.button.copyWith(fontSize: isSmall ? 11 : 13),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: isSmall ? 14 : 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: AppTypography.button.copyWith(fontSize: isSmall ? 11 : 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.child,
    required this.onPressed,
    required this.isSmall,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmall ? 8 : 14,
                horizontal: 24,
              ),
              child: Center(
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

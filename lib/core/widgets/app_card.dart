import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppCardTone { neutral, success, muted }

/// Generic bordered/rounded surface used for job cards, profile fields,
/// resume-type cards, etc. [tone] switches between the neutral, success
/// (green) and muted backgrounds seen throughout the design.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppCardTone.neutral,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.boxShadow,
    this.borderRadius,
  });

  final Widget child;
  final AppCardTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bg, border) = switch (tone) {
      AppCardTone.neutral => (
        isDark ? AppColors.surfaceDark : AppColors.surface,
        isDark ? AppColors.borderDark : AppColors.border,
      ),
      AppCardTone.success => (
        isDark ? AppColors.successDark : AppColors.surfaceSuccess,
        isDark ? AppColors.success : AppColors.borderSuccess,
      ),
      AppCardTone.muted => (
        isDark ? AppColors.backgroundDark : AppColors.surfaceMuted,
        isDark ? AppColors.borderDark : AppColors.border,
      ),
    };

    final defaultShadows = [
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A111827),
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
    ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1.0,
        ),
        boxShadow: boxShadow ?? defaultShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

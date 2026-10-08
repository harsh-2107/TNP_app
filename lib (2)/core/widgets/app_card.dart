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
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.boxShadow,
  });

  final Widget child;
  final AppCardTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;

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
      // Top-left light highlight (intensified)
      BoxShadow(
        color: isDark ? AppColors.shadowLightDark : AppColors.shadowLight,
        offset: const Offset(-8, -8),
        blurRadius: 16,
        spreadRadius: 2,
      ),
      // Bottom-right dark shadow (intensified)
      BoxShadow(
        color: isDark
            ? AppColors.shadowDarkDark
            : AppColors.shadowDark.withOpacity(
                0.5,
              ), // softened slightly to balance dark color
        offset: const Offset(8, 8),
        blurRadius: 16,
        spreadRadius: 2,
      ),
    ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          0,
        ), // Increased radius for claymorphic feel
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white, // Pure white rim for starker molded look
          width: 2.0, // Thicker molding
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

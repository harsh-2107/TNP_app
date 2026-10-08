import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

enum AppChipTone { success, neutral, warning, error }

/// Small pill badge — the "Eligible" badge on job cards, status labels
/// elsewhere. [tone] controls the color pairing.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppChipTone.success,
  });

  final String label;
  final IconData? icon;
  final AppChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AppChipTone.success => (AppColors.successBg, AppColors.success),
      AppChipTone.neutral => (AppColors.border, AppColors.textSecondary),
      AppChipTone.warning => (const Color(0xFFFEF3C7), AppColors.warning),
      AppChipTone.error => (AppColors.errorBg, AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

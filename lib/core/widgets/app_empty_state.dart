import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';

/// Consistent empty state (no jobs, no notifications, no resumes yet)
/// instead of leaving a screen blank while there's genuinely nothing to
/// show.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    this.title = AppStrings.noDataTitle,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Consistent error state with an optional retry action. Controllers
/// expose a [Failure]; screens pass its `.message` straight through here.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.title = AppStrings.genericErrorTitle,
    this.message = AppStrings.genericErrorMessage,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
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
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: AppStrings.retry,
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Centralized confirmation/alert dialog so every "Are you sure?" prompt
/// in the app looks the same.
class AppDialog {
  const AppDialog._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? AppColors.error : AppColors.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void showInfo(BuildContext context, {required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          AppButton(
            label: 'OK',
            isFullWidth: false,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-bleed loading state. Use inside the `AsyncValue.when(loading: ...)`
/// branch so every screen shows a consistent spinner instead of a blank
/// frame.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Small inline loader (e.g. within a button-adjacent row).
class AppInlineLoader extends StatelessWidget {
  const AppInlineLoader({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Gradient app bar used for simple, non-scrollable header pages
/// (Notifications, Upload Resume, Create Resume). For the richer Home /
/// Profile headers with avatars & summaries, compose [AppColors.primaryGradient]
/// directly in those feature widgets instead.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: AppBar(
        title: Text(title, style: AppTypography.titleMedium.copyWith(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
    );
  }
}

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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
      actions: actions,
      leading: leading ??
          (automaticallyImplyLeading && canPop
              ? Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null),
      automaticallyImplyLeading: false,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:place_row/core/widgets/app_animated_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Bottom navigation bar matching the 5-tab design (Home / Resume / Add /
/// Notify / Profile). Driven entirely by [items] + [currentIndex] so the
/// tab set can change without touching this widget.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultShadows = [
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.4) : const Color(0x12111827),
        offset: const Offset(0, 4),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1.0,
          ),
          boxShadow: defaultShadows,
        ),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItemView(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: selected
            ? BoxDecoration(
                color: isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            (selected && !kDebugMode)
                ? FlipIcon(icon: Icon(item.icon, size: 20, color: color))
                : Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// The semi-transparent circular icon buttons in the header ("bell",
/// "user" icons on Home). Kept as its own widget so the hover/opacity
/// behavior isn't reimplemented per screen.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.badgeCount,
    this.color = Colors.white,
    this.background = const Color(0x26FFFFFF),
    this.size = 36,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int? badgeCount;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox(
              height: size,
              width: size,
              child: Icon(icon, size: 16, color: color),
            ),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
              child: Text(
                badgeCount! > 9 ? '9+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

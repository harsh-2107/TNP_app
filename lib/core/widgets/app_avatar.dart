import 'package:flutter/material.dart';
import '../extensions/string_extensions.dart';

/// Circular avatar — falls back to initials/person icon when no
/// [imageUrl] is available, matching the profile header mockup.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 70,
    this.background = const Color(0x40FFFFFF),
    this.foreground = Colors.white,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    if (!name.isNullOrEmpty) {
      return Text(
        name!.initials,
        style: TextStyle(color: foreground, fontSize: size * 0.32, fontWeight: FontWeight.w700),
      );
    }
    return Icon(Icons.person_rounded, color: foreground, size: size * 0.46);
  }
}

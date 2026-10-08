import 'dart:math';

import 'package:flutter/material.dart';

class FlipIcon extends StatefulWidget {
  const FlipIcon({super.key, this.icon});
  final Icon? icon;
  @override
  State<FlipIcon> createState() => _FlipIconState();
}

class _FlipIconState extends State<FlipIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final angle = controller.value * 2 * pi;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: child,
        );
      },
      child: widget.icon,
    );
  }
}

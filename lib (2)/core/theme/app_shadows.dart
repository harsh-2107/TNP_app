import 'package:flutter/material.dart';

/// Centralized elevation/shadow presets.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x1F0F766E),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> none = [];
}

import 'package:flutter/material.dart';

/// Centralized elevation/shadow presets.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A111827),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x141668FE),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primaryCard = [
    BoxShadow(
      color: Color(0x2E1668FE),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> ctaButton = [
    BoxShadow(
      color: Color(0x38FA5A16),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> none = [];
}

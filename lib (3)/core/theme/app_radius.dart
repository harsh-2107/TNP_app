import 'package:flutter/material.dart';

/// Centralized corner-radius scale.
class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 16;
  static const double pill = 999;

  static BorderRadius get borderXs => BorderRadius.circular(xs);
  static BorderRadius get borderSm => BorderRadius.circular(sm);
  static BorderRadius get borderMd => BorderRadius.circular(md);
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  static BorderRadius get borderPill => BorderRadius.circular(pill);
}

import 'package:flutter/material.dart';

/// Brand + neutral tokens mirrored from `frontend/app/globals.css` and the
/// Crimson ramp in `frontend/lib/colorThemes.ts`.
abstract final class Brand {
  static const crimson50 = Color(0xFFFCEDEF);
  static const crimson100 = Color(0xFFF9DCE0);
  static const crimson200 = Color(0xFFF3B6BF);
  static const crimson400 = Color(0xFFEA4A5A);
  static const crimson500 = Color(0xFFF0140A);
  static const crimson600 = Color(0xFFD4031A);
  static const crimson700 = Color(0xFFB8002E);
  static const crimson900 = Color(0xFF5C0012);

  static const bgLight = Color(0xFFF4F4F5);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF3F3638);
  static const mutedLight = Color(0xFF7A7174);
  static const borderLight = Color(0xFFE6E3E4);

  static const bgDark = Color(0xFF0B0A0B);
  static const surfaceDark = Color(0xFF161415);
  static const textDark = Color(0xFFECE4E5);
  static const mutedDark = Color(0xFFA59C9E);
  static const borderDark = Color(0xFF2A2627);
}

/// Semantic status colours used by chips, amounts and badges.
abstract final class StatusColors {
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const neutral = Color(0xFF71717A);
}

abstract final class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const control = 10.0; // --radius: 0.625rem
  static const card = 14.0;
  static const sheet = 20.0;
}

/// Layout breakpoints used by the responsive shell and grids.
abstract final class Breakpoints {
  static const compact = 600.0;
  static const expanded = 1024.0;

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compact;
  static bool isExpanded(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= expanded;

  /// Column count for card grids at the current width.
  static int columns(
    BuildContext c, {
    int compactCols = 2,
    int mediumCols = 3,
    int expandedCols = 4,
  }) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= expanded) return expandedCols;
    if (w >= compact) return mediumCols;
    return compactCols;
  }
}

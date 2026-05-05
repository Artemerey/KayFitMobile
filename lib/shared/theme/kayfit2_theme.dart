// Kayfit 2.0 design tokens — see specs/kayfit_2.0/HLD_kayfit_2.0_redesign.md
//
// Radically minimal: monochrome surface + Apple Activity ring colors.
// Single accent: Apple system blue (#007AFF).

import 'package:flutter/material.dart';

class K2Colors {
  const K2Colors._();

  // ── Light theme ────────────────────────────────────────────────────────────
  static const lightBg = Color(0xFFFAFAFA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightFg = Color(0xFF0A0A0A);
  static const lightFgDim = Color(0xFF737373);
  static const lightFgMute = Color(0xFFA3A3A3);
  static const lightBorder = Color(0xFFE5E5E5);
  static const lightBorderStrong = Color(0xFFD4D4D4);
  static const lightHairline = Color(0xFFEFEFEF);

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static const darkBg = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF0A0A0A);
  static const darkCard = Color(0xFF141414);
  static const darkFg = Color(0xFFFAFAFA);
  static const darkFgDim = Color(0xFF888888);
  static const darkFgMute = Color(0xFF555555);
  static const darkBorder = Color(0xFF1F1F1F);
  static const darkBorderStrong = Color(0xFF2A2A2A);
  static const darkHairline = Color(0xFF1A1A1A);

  // ── Single accent ──────────────────────────────────────────────────────────
  static const accent = Color(0xFF007AFF); // Apple system blue
  static const accentLight = Color(0xFF5AC8FA);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const error = Color(0xFFFF3B30); // Apple system red
}

/// Apple Activity ring colors (Move/Exercise/Stand/Workout) mapped to KayFit
/// macros.
class K2RingColors {
  const K2RingColors({
    required this.from,
    required this.to,
    required this.trackLight,
    required this.trackDark,
  });

  final Color from;
  final Color to;
  final Color trackLight;
  final Color trackDark;

  /// Move (red/pink) — kcal.
  static const kcal = K2RingColors(
    from: Color(0xFFFF2D55),
    to: Color(0xFFFF375F),
    trackLight: Color(0x1FFF375F), // ~12% alpha
    trackDark: Color(0x2EFF375F), // ~18% alpha
  );

  /// Exercise (green/lime) — protein.
  static const protein = K2RingColors(
    from: Color(0xFFA6FF00),
    to: Color(0xFF76E60E),
    trackLight: Color(0x2476E60E),
    trackDark: Color(0x2EA6FF00),
  );

  /// Stand (cyan) — carbs.
  static const carbs = K2RingColors(
    from: Color(0xFF1ECEDA),
    to: Color(0xFF3FE9FF),
    trackLight: Color(0x241ECEDA),
    trackDark: Color(0x2E1ECEDA),
  );

  /// Workout (orange/yellow) — fat.
  static const fat = K2RingColors(
    from: Color(0xFFFF9500),
    to: Color(0xFFFFCC00),
    trackLight: Color(0x24FF9500),
    trackDark: Color(0x2EFF9500),
  );
}

/// Per-day status colors for the calendar strip / month grid.
class K2CalendarStatus {
  const K2CalendarStatus._();

  /// Within calorie goal — green ring.
  static const goodRing = Color(0xFF34C759);
  static const goodTrack = Color(0x2E34C759); // 18% alpha

  /// Over calorie goal — red ring.
  static const overRing = Color(0xFFFF3B30);
  static const overTrack = Color(0x2EFF3B30);
}

/// Font family resolution. The actual ttf assets are wired in pubspec.yaml.
/// If Geist / JetBrains Mono aren't bundled, Flutter falls back to system.
class K2Fonts {
  const K2Fonts._();

  /// Primary UI font.
  static const sans = 'Geist';

  /// Numeric font for kcal / macros / time / weights.
  static const mono = 'JetBrainsMono';
}

/// Convenience theme bundle the Kayfit 2.0 widgets read.
@immutable
class K2Theme {
  const K2Theme({
    required this.bg,
    required this.surface,
    required this.card,
    required this.fg,
    required this.fgDim,
    required this.fgMute,
    required this.border,
    required this.borderStrong,
    required this.hairline,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color fg;
  final Color fgDim;
  final Color fgMute;
  final Color border;
  final Color borderStrong;
  final Color hairline;
  final bool isDark;

  /// Single accent — Apple system blue.
  Color get accent => K2Colors.accent;

  static const K2Theme light = K2Theme(
    bg: K2Colors.lightBg,
    surface: K2Colors.lightSurface,
    card: K2Colors.lightCard,
    fg: K2Colors.lightFg,
    fgDim: K2Colors.lightFgDim,
    fgMute: K2Colors.lightFgMute,
    border: K2Colors.lightBorder,
    borderStrong: K2Colors.lightBorderStrong,
    hairline: K2Colors.lightHairline,
    isDark: false,
  );

  static const K2Theme dark = K2Theme(
    bg: K2Colors.darkBg,
    surface: K2Colors.darkSurface,
    card: K2Colors.darkCard,
    fg: K2Colors.darkFg,
    fgDim: K2Colors.darkFgDim,
    fgMute: K2Colors.darkFgMute,
    border: K2Colors.darkBorder,
    borderStrong: K2Colors.darkBorderStrong,
    hairline: K2Colors.darkHairline,
    isDark: true,
  );
}

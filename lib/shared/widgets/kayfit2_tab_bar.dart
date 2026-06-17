// KF2-FOUND-3 · Tab bar Apple-style
//
// Three tabs (Journal | Recipes | Chat) with a centre gradient "+" button.
// Spec: specs/kayfit_2.0/source_handoff/project/kayfit-app.jsx  TabBar 495-543
//
// Layout:
//   [ Journal tab ] [ Recipes tab ]  [ + button 88px wide ]  [ Chat tab ]
//
// Visual system:
//   • BackdropFilter  blur(20) for the frosted-glass effect
//   • 0.5 px hairline top border (1 logical px / devicePixelRatio)
//   • Gradient circle button: #5AC8FA → #007AFF  (135°)
//   • Active tab colour = K2Colors.accent (#007AFF)
//   • Inactive tab colour = #8E8E93

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/i18n/generated/app_localizations.dart';
import '../theme/kayfit2_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab-bar widget
// ─────────────────────────────────────────────────────────────────────────────

class Kayfit2TabBar extends StatelessWidget {
  const Kayfit2TabBar({
    super.key,
    required this.theme,
    required this.active,
    required this.onTab,
    required this.onAdd,
  });

  /// Current Kayfit 2.0 theme bundle (light or dark).
  final K2Theme theme;

  /// Currently active tab key: `'journal'`, `'recipes'`, or `'chat'`.
  final String active;

  /// Called when a tab is tapped.  Receives the tab key.
  final ValueChanged<String> onTab;

  /// Called when the centre "+" button is tapped.
  final VoidCallback onAdd;

  // ── Design constants ──────────────────────────────────────────────────────

  static const _kMinHeight = 64.0;
  static const _kPaddingTop = 4.0;
  static const _kPaddingBottom = 6.0;
  static const _kAddButtonWidth = 88.0;
  static const _kAddCircleSize = 44.0;
  static const _kTabIconSize = 24.0;
  static const _kLabelSize = 10.0;
  static const _kInactiveColor = Color(0xFF8E8E93);

  // Hairline top-border colours (spec: rgba with alpha)
  static const _kBorderLight = Color(0x1A000000); // rgba(0,0,0,0.10)
  static const _kBorderDark = Color(0x1EFFFFFF); // rgba(255,255,255,0.12)

  // Frosted-glass background colours (spec: 0.92 opacity)
  static const _kBgLight = Color(0xEBFFFFFF); // white 0.92  ≈ 0xEB
  static const _kBgDark = Color(0xEB141416); // #141416 0.92 ≈ 0xEB

  // Gradient for the centre circle: 135° #5AC8FA → #007AFF
  static const _kAddGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [K2Colors.accentLight, K2Colors.accent],
  );

  // Shadow for the centre circle
  static const _kAddShadow = [
    BoxShadow(
      color: Color(0x6B007AFF), // rgba(0,122,255,0.42)
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.10)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.isDark;
    final borderColor = isDark ? _kBorderDark : _kBorderLight;
    final bgColor = isDark ? _kBgDark : _kBgLight;

    // The frosted glass effect requires:
    //   ClipRect → BackdropFilter → Container(color)
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kMinHeight),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                color: borderColor,
                // 0.5 logical px — closest Flutter can do without MediaQuery
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                top: _kPaddingTop,
                bottom: _kPaddingBottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Journal tab
                  Expanded(
                    child: _TabItem(
                      tabKey: 'journal',
                      label: l10n.nav_journal,
                      icon: Icons.menu_book_rounded,
                      active: active == 'journal',
                      onTap: onTab,
                    ),
                  ),

                  // Recipes tab — Ишка's RAG picks for the day.
                  Expanded(
                    child: _TabItem(
                      tabKey: 'recipes',
                      label: l10n.nav_recipes,
                      icon: Icons.restaurant_menu_rounded,
                      active: active == 'recipes',
                      onTap: onTab,
                    ),
                  ),

                  // Centre "+" button
                  SizedBox(
                    width: _kAddButtonWidth,
                    child: _AddButton(
                      onTap: onAdd,
                      accentColor: K2Colors.accent,
                      label: l10n.nav_add,
                    ),
                  ),

                  // Chat tab
                  Expanded(
                    child: _TabItem(
                      tabKey: 'chat',
                      label: l10n.nav_chat,
                      icon: Icons.chat_bubble_outline_rounded,
                      active: active == 'chat',
                      onTap: onTab,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: single tab item (Journal / Chat)
// ─────────────────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tabKey,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String tabKey;
  final String label;
  final IconData icon;
  final bool active;
  final ValueChanged<String> onTap;

  static const _kActiveColor = K2Colors.accent;
  static const _kInactiveColor = Kayfit2TabBar._kInactiveColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? _kActiveColor : _kInactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(tabKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Icon — Material icons don't expose strokeWidth, so we rely on
            // the visual weight difference between active/inactive via size and
            // colour. An outlined/filled icon pair conveys the same intent.
            Icon(
              icon,
              size: Kayfit2TabBar._kTabIconSize,
              color: color,
              // Subtle scale-up when active to reinforce the selection
              grade: active ? 200 : 0,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: Kayfit2TabBar._kLabelSize,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                color: color,
                fontFamily: K2Fonts.sans,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: centre "+" add button
// ─────────────────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.onTap,
    required this.accentColor,
    required this.label,
  });

  final VoidCallback onTap;
  final Color accentColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Gradient circle
            Container(
              width: Kayfit2TabBar._kAddCircleSize,
              height: Kayfit2TabBar._kAddCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Kayfit2TabBar._kAddGradient,
                boxShadow: Kayfit2TabBar._kAddShadow,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // "Add" label
            Text(
              label,
              style: TextStyle(
                fontSize: Kayfit2TabBar._kLabelSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: accentColor,
                fontFamily: K2Fonts.sans,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kayfit/core/analytics/analytics_service.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/core/locale/locale_provider.dart';
import 'package:kayfit/features/body_form/body_form_prefs.dart';
import 'package:kayfit/features/body_form/i18n/body_form_strings.dart';
import 'package:kayfit/features/body_form/screens/body_form_screen.dart';
import 'package:kayfit/features/settings/screens/document_screen.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';

// Provider that surfaces the singleton Dio instance for fire-and-forget
// language sync — mirrors the approach used in SettingsScreen.
final _apiDioProvider = Provider<Dio>((_) => apiDio);

// ─── Screen ────────────────────────────────────────────────────────────────────

class SettingsV2Screen extends ConsumerStatefulWidget {
  const SettingsV2Screen({super.key});

  @override
  ConsumerState<SettingsV2Screen> createState() => _SettingsV2ScreenState();
}

class _SettingsV2ScreenState extends ConsumerState<SettingsV2Screen> {
  @override
  void initState() {
    super.initState();
    // Defer analytics until after the first frame so the widget tree fully
    // mounts before any Firebase call fires.  This also makes the call safe
    // to drain in widget tests via tester.takeException().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _track(AnalyticsService.settingsOpened);
    });
  }

  Future<void> _openBodyForm(BuildContext context) async {
    final saved = await BodyFormPrefs.load();
    final prefs = await SharedPreferences.getInstance();
    var gender = '';
    final raw = prefs.getString('onboarding_answers');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          gender = decoded['gender'] as String? ?? '';
        }
      } on FormatException {
        // Malformed JSON — fall back to empty gender (male assets).
      }
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BodyFormScreen(
          isOnboarding: false,
          gender: gender,
          initialCurrent: saved?.current ?? 0,
          initialDesired: saved?.desired ?? 0,
        ),
      ),
    );
  }

  /// Fire-and-forget analytics call that never throws.  Firebase may not be
  /// initialised in test environments — we must not let that break user flows.
  static void _track(void Function() fn) {
    try {
      fn();
    } on Exception {
      // Analytics failures are non-fatal — ignore silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authNotifierProvider).value;
    final currentLocale = ref.watch(localeProvider);
    final isRu = currentLocale.languageCode == 'ru';

    // Resolve K2 theme from system brightness.
    final brightness = MediaQuery.platformBrightnessOf(context);
    final t = brightness == Brightness.dark ? K2Theme.dark : K2Theme.light;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(t: t, l10n: l10n),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── Profile card ─────────────────────────────────────────
                  if (user != null) ...[
                    const SizedBox(height: 20),
                    _ProfileCard(t: t, user: user),
                  ],

                  // ── Goal & macros ────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionHeader(t: t, label: 'Goal & Macros'),
                  const SizedBox(height: 4),
                  _SectionGroup(
                    t: t,
                    children: [
                      _Row(
                        t: t,
                        icon: Icons.flag_outlined,
                        label: l10n.settings_goals,
                        onTap: () {
                          _track(AnalyticsService.settingsGoalsTapped);
                          context.push('/settings/goals');
                        },
                      ),
                      _Row(
                        t: t,
                        icon: Icons.accessibility_new_outlined,
                        label: BodyFormStrings.settingsLabel(isRu),
                        onTap: () => _openBodyForm(context),
                      ),
                    ],
                  ),

                  // ── Preferences ──────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionHeader(t: t, label: 'Preferences'),
                  const SizedBox(height: 4),
                  _SectionGroup(
                    t: t,
                    children: [
                      _LanguageToggleRow(
                        t: t,
                        l10n: l10n,
                        isRu: isRu,
                        onSelect: (locale) {
                          _track(AnalyticsService.settingsLanguageTapped);
                          ref
                              .read(localeProvider.notifier)
                              .setLocale(locale);
                          _syncLanguageToBackend(locale.languageCode);
                        },
                      ),
                    ],
                  ),

                  // ── AI Data Processing ───────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionHeader(t: t, label: 'AI & Data'),
                  const SizedBox(height: 4),
                  _SectionGroup(
                    t: t,
                    children: [
                      _Row(
                        t: t,
                        icon: Icons.psychology_outlined,
                        label: l10n.settings_ai_consent,
                        onTap: () => context.push('/ai-consent'),
                      ),
                    ],
                  ),

                  // ── About ────────────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionHeader(t: t, label: 'About'),
                  const SizedBox(height: 4),
                  _SectionGroup(
                    t: t,
                    children: [
                      _Row(
                        t: t,
                        icon: Icons.privacy_tip_outlined,
                        label: l10n.settings_privacy_policy,
                        onTap: () {
                          _track(AnalyticsService.settingsPrivacyTapped);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentScreen(
                                  type: DocumentType.privacyPolicy),
                            ),
                          );
                        },
                      ),
                      _HairlineDivider(t: t),
                      _Row(
                        t: t,
                        icon: Icons.description_outlined,
                        label: l10n.settings_terms,
                        onTap: () {
                          _track(AnalyticsService.settingsTermsTapped);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentScreen(
                                  type: DocumentType.termsOfService),
                            ),
                          );
                        },
                      ),
                      _HairlineDivider(t: t),
                      _Row(
                        t: t,
                        icon: Icons.info_outline,
                        label: 'Version',
                        trailing: Text(
                          '1.0.0',
                          style: TextStyle(
                            fontFamily: K2Fonts.mono,
                            fontSize: 13,
                            color: t.fgDim,
                          ),
                        ),
                        showChevron: false,
                        onTap: null,
                      ),
                    ],
                  ),

                  // ── Sign out ─────────────────────────────────────────────
                  const SizedBox(height: 20),
                  _SectionGroup(
                    t: t,
                    children: [
                      _Row(
                        t: t,
                        icon: Icons.logout_outlined,
                        label: l10n.settings_logout,
                        labelColor: K2Colors.error,
                        iconColor: K2Colors.error,
                        showChevron: false,
                        onTap: () {
                          _track(AnalyticsService.settingsLogoutTapped);
                          _track(AnalyticsService.loggedOut);
                          ref.read(authNotifierProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),

                  // ── Delete account ───────────────────────────────────────
                  const SizedBox(height: 8),
                  _SectionGroup(
                    t: t,
                    children: [
                      _Row(
                        t: t,
                        icon: Icons.person_remove_outlined,
                        label: l10n.settings_delete_account_btn,
                        labelColor: K2Colors.error,
                        iconColor: K2Colors.error,
                        showChevron: false,
                        onTap: () {
                          _track(AnalyticsService.settingsDeleteAccountTapped);
                          _confirmDeleteAccount(context, l10n);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.settings_delete_account_title,
          style: const TextStyle(
            fontFamily: K2Fonts.sans,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        content: Text(
          l10n.settings_delete_account_body,
          style: TextStyle(
            fontFamily: K2Fonts.sans,
            fontSize: 14,
            color: K2Colors.lightFgDim,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _track(AnalyticsService.deleteAccountCancelled);
              Navigator.pop(ctx);
            },
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                color: K2Colors.accent,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              _track(AnalyticsService.deleteAccountConfirmed);
              Navigator.pop(ctx);
              try {
                await ref
                    .read(authNotifierProvider.notifier)
                    .deleteAccount();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.error_unknown)),
                  );
                }
              }
            },
            child: Text(
              l10n.common_delete,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                color: K2Colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _syncLanguageToBackend(String langCode) {
    final dio = ref.read(_apiDioProvider);
    unawaited(_postLanguage(dio, langCode));
  }

  static Future<void> _postLanguage(Dio dio, String langCode) async {
    try {
      await dio.post('/api/profile', data: {'language': langCode});
    } on Exception {
      // Silently ignore — locale is already applied locally.
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — KF2 style with back button and hairline border
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.t, required this.l10n});

  final K2Theme t;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          bottom: BorderSide(color: t.hairline, width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            // Back button — left side
            IconButton(
              key: const Key('settings_v2_back'),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: t.fg,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/journal-v2');
                }
              },
            ),
            // Centred title via Expanded + Center
            Expanded(
              child: Center(
                child: Text(
                  'settings',
                  key: const Key('settings_v2_title'),
                  style: TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: t.fg,
                  ),
                ),
              ),
            ),
            // Balance spacer matching back button width.
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card — KF2 monochrome
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.t, required this.user});

  final K2Theme t;
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.fg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initial(user),
                style: TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.bg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username ?? user.email ?? 'User',
                  style: TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email as String,
                    style: TextStyle(
                      fontFamily: K2Fonts.mono,
                      fontSize: 12,
                      color: t.fgDim,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(dynamic user) {
    final name = (user.username ?? user.email ?? 'U') as String;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.t, required this.label});

  final K2Theme t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: K2Fonts.sans,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: t.fgMute,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section group — white card with hairline borders
// ─────────────────────────────────────────────────────────────────────────────

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.t, required this.children});

  final K2Theme t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hairline divider — 0.5 px, indented to align with label
// ─────────────────────────────────────────────────────────────────────────────

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider({required this.t});

  final K2Theme t;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0,
      thickness: 0.5,
      indent: 48,
      color: t.hairline,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row — generic settings row
// ─────────────────────────────────────────────────────────────────────────────

class _Row extends StatefulWidget {
  const _Row({
    required this.t,
    required this.icon,
    required this.label,
    this.trailing,
    this.showChevron = true,
    this.labelColor,
    this.iconColor,
    required this.onTap,
  });

  final K2Theme t;
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool showChevron;
  final Color? labelColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;
    final effectiveLabelColor =
        widget.labelColor ?? widget.t.fg;
    final effectiveIconColor =
        widget.iconColor ?? widget.t.fgDim;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isInteractive
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: isInteractive
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: isInteractive
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? widget.t.hairline.withValues(alpha: 0.8)
            : Colors.transparent,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 20,
              color: effectiveIconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: effectiveLabelColor,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              widget.trailing!,
              const SizedBox(width: 4),
            ],
            if (widget.showChevron && isInteractive)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: widget.t.fgMute,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline language toggle row — RU | EN segment control
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageToggleRow extends StatelessWidget {
  const _LanguageToggleRow({
    required this.t,
    required this.l10n,
    required this.isRu,
    required this.onSelect,
  });

  final K2Theme t;
  final AppLocalizations l10n;
  final bool isRu;
  final void Function(Locale) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.language_outlined, size: 20, color: t.fgDim),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.settings_language,
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: t.fg,
              ),
            ),
          ),
          _LangSegment(t: t, isRu: isRu, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _LangSegment extends StatelessWidget {
  const _LangSegment({
    required this.t,
    required this.isRu,
    required this.onSelect,
  });

  final K2Theme t;
  final bool isRu;
  final void Function(Locale) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            t: t,
            label: 'RU',
            selected: isRu,
            isFirst: true,
            onTap: () => onSelect(const Locale('ru')),
          ),
          Container(width: 0.5, height: 36, color: t.border),
          _SegBtn(
            t: t,
            label: 'EN',
            selected: !isRu,
            isFirst: false,
            onTap: () => onSelect(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatefulWidget {
  const _SegBtn({
    required this.t,
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.onTap,
  });

  final K2Theme t;
  final String label;
  final bool selected;
  final bool isFirst;
  final VoidCallback onTap;

  @override
  State<_SegBtn> createState() => _SegBtnState();
}

class _SegBtnState extends State<_SegBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: widget.isFirst ? const Radius.circular(9) : Radius.zero,
      right: widget.isFirst ? Radius.zero : const Radius.circular(9),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 52,
        height: 36,
        decoration: BoxDecoration(
          color: widget.selected
              ? K2Colors.accent
              : _pressed
                  ? widget.t.hairline
                  : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontFamily: K2Fonts.mono,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: widget.selected ? Colors.white : widget.t.fgDim,
          ),
        ),
      ),
    );
  }
}


import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../body_form/body_form_prefs.dart';
import '../../body_form/i18n/body_form_strings.dart';
import '../../body_form/screens/body_form_screen.dart';
import 'document_screen.dart';

// Provider that surfaces the singleton Dio instance to the settings screen
// for fire-and-forget profile language sync. Avoids direct global access.
final _apiDioProvider = Provider<Dio>((_) => apiDio);

// ─── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    AnalyticsService.settingsOpened();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
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

  Animation<double> _fadeFor(int i) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(
          (i * 0.12).clamp(0.0, 0.7),
          ((i * 0.12) + 0.35).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );

  Animation<Offset> _slideFor(int i) => Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(
          (i * 0.12).clamp(0.0, 0.7),
          ((i * 0.12) + 0.35).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authNotifierProvider).value;
    final currentLocale = ref.watch(localeProvider);
    final isRu = currentLocale.languageCode == 'ru';

    final sections = <Widget>[
      if (user != null) _UserCard(user: user),
      const SizedBox(height: 8),
      _SectionCard(children: [
        _NavItem(
          icon: Icons.flag_rounded,
          iconColor: AppColors.accent,
          iconBg: AppColors.accentSoft,
          label: l10n.settings_goals,
          onTap: () {
            AnalyticsService.settingsGoalsTapped();
            context.push('/settings/goals');
          },
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.accessibility_new_rounded,
          iconColor: AppColors.accent,
          iconBg: AppColors.accentSoft,
          label: BodyFormStrings.settingsLabel(isRu),
          onTap: () => _openBodyForm(context),
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.language_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBg: const Color(0xFFEDE9FE),
          label: l10n.settings_language,
          onTap: () {
            AnalyticsService.settingsLanguageTapped();
            _showLangSheet(context, l10n, isRu);
          },
          trailing: Text(
            isRu ? '🇷🇺 RU' : '🇬🇧 EN',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      _SectionCard(children: [
        _NavItem(
          icon: Icons.smart_toy_rounded,
          iconColor: AppColors.accent,
          iconBg: AppColors.accentSoft,
          label: l10n.settings_ai_consent,
          onTap: () => context.push('/ai-consent'),
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.auto_awesome_rounded,
          iconColor: const Color(0xFF007AFF),
          iconBg: const Color(0x1A007AFF),
          label: 'Kayfit 2.0 · Preview',
          onTap: () => context.push('/kayfit2/preview'),
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.privacy_tip_rounded,
          iconColor: AppColors.warm,
          iconBg: AppColors.warmSoft,
          label: l10n.settings_privacy_policy,
          onTap: () {
            AnalyticsService.settingsPrivacyTapped();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const DocumentScreen(type: DocumentType.privacyPolicy),
              ),
            );
          },
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.description_rounded,
          iconColor: AppColors.support,
          iconBg: AppColors.supportSoft,
          label: l10n.settings_terms,
          onTap: () {
            AnalyticsService.settingsTermsTapped();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const DocumentScreen(type: DocumentType.termsOfService),
              ),
            );
          },
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.warm,
          iconBg: AppColors.warmSoft,
          label: l10n.settings_subscription_terms,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const DocumentScreen(type: DocumentType.subscriptionTerms),
            ),
          ),
        ),
        _ItemDivider(),
        _NavItem(
          icon: Icons.payment_rounded,
          iconColor: AppColors.support,
          iconBg: AppColors.supportSoft,
          label: l10n.settings_subscription_privacy,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const DocumentScreen(type: DocumentType.subscriptionPrivacy),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      _LogoutCard(
        label: l10n.settings_logout,
        onTap: () {
          AnalyticsService.settingsLogoutTapped();
          AnalyticsService.loggedOut();
          ref.read(authNotifierProvider.notifier).logout();
        },
      ),
      const SizedBox(height: 8),
      _DeleteAccountCard(
        onTap: () {
          AnalyticsService.settingsDeleteAccountTapped();
          _confirmDeleteAccount(context);
        },
      ),
      const SizedBox(height: 24),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient AppBar ──────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                l10n.settings_title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDCFCE7), Color(0xFFF4F6F8)],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => FadeTransition(
                  opacity: _fadeFor(index),
                  child: SlideTransition(
                    position: _slideFor(index),
                    child: sections[index],
                  ),
                ),
                childCount: sections.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.settings_delete_account_title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          l10n.settings_delete_account_body,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AnalyticsService.deleteAccountCancelled();
              Navigator.pop(ctx);
            },
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              AnalyticsService.deleteAccountConfirmed();
              Navigator.pop(ctx);
              try {
                await ref.read(authNotifierProvider.notifier).deleteAccount();
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
                color: AppColors.accentOver,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLangSheet(
    BuildContext context,
    AppLocalizations l10n,
    bool isRu,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LangSheet(
        currentIsRu: isRu,
        l10n: l10n,
        onSelect: (newLocale) {
          ref.read(localeProvider.notifier).setLocale(newLocale);
          Navigator.pop(context);
          // Fire-and-forget: sync language preference to backend profile.
          _syncLanguageToBackend(newLocale.languageCode);
        },
      ),
    );
  }

  void _syncLanguageToBackend(String langCode) {
    // Intentionally unawaited — language change in UI must not block on network.
    final dio = ref.read(_apiDioProvider);
    unawaited(_postLanguage(dio, langCode));
  }

  static Future<void> _postLanguage(Dio dio, String langCode) async {
    try {
      await dio.post('/api/profile', data: {'language': langCode});
    } on Exception {
      // Silently ignore — locale is already applied locally via SharedPrefs.
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final dynamic user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E1F), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'user_card',
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username ?? user.email ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.sm,
      ),
      child: Column(children: children),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, color: AppColors.border);
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed
            ? AppColors.accentSoft.withValues(alpha: 0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Color icon badge
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            widget.trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout card
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _LogoutCard({required this.label, required this.onTap});

  @override
  State<_LogoutCard> createState() => _LogoutCardState();
}

class _LogoutCardState extends State<_LogoutCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color:
              _pressed ? AppColors.accentOverSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.sm,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentOverSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.accentOver, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.accentOver,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language option
// ─────────────────────────────────────────────────────────────────────────────

class _LangOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.accent : AppColors.text,
              ),
            ),
            const Spacer(),
            AnimatedScale(
              scale: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.elasticOut,
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete account card
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteAccountCard extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteAccountCard({required this.onTap});

  @override
  State<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends State<_DeleteAccountCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.accentOverSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.sm,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentOverSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.person_remove_rounded,
                color: AppColors.accentOver,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.settings_delete_account_btn,
              style: const TextStyle(
                color: AppColors.accentOver,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language picker bottom sheet (stateless — reads locale from ProviderScope)
// ─────────────────────────────────────────────────────────────────────────────

class _LangSheet extends StatelessWidget {
  const _LangSheet({
    required this.currentIsRu,
    required this.l10n,
    required this.onSelect,
  });

  final bool currentIsRu;
  final AppLocalizations l10n;
  final void Function(Locale) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            l10n.settings_language,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _LangOption(
            flag: '🇷🇺',
            label: l10n.settings_langRu,
            selected: currentIsRu,
            onTap: () => onSelect(const Locale('ru')),
          ),
          const SizedBox(height: 10),
          _LangOption(
            flag: '🇬🇧',
            label: l10n.settings_langEn,
            selected: !currentIsRu,
            onTap: () => onSelect(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

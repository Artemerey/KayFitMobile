import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/core/analytics/analytics_service.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/onboarding_sync.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/features/dashboard/providers/dashboard_provider.dart';
import 'package:kayfit/features/way_to_goal/providers/way_to_goal_provider.dart';
import 'package:kayfit/router.dart';
import 'package:kayfit/shared/theme/app_theme.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  bool _isLogin = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OBColors.bg,
      body: Column(
        children: [
          _Header(
            isLogin: _isLogin,
            onToggle: (v) => setState(() => _isLogin = v),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isLogin
                    ? _LoginForm(key: const ValueKey('login'))
                    : _RegisterForm(key: const ValueKey('register')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _Header({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: OBColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + tab toggle row
              Row(
                children: [
                  _BackButton(),
                  const Spacer(),
                  _TabToggle(isLogin: isLogin, onToggle: onToggle),
                ],
              ),
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.mail_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isLogin
                    ? AppLocalizations.of(context)!.auth_email_login_title
                    : AppLocalizations.of(context)!.auth_register_title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLogin
                    ? AppLocalizations.of(context)!.auth_login_subtitle
                    : AppLocalizations.of(context)!.auth_register_subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AnalyticsService.tap('email_auth', 'back');
        Navigator.of(context).pop();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _TabToggle({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabChip(label: AppLocalizations.of(context)!.auth_tab_login, active: isLogin, onTap: () {
            AnalyticsService.authTabSwitched('login');
            onToggle(true);
          }),
          _TabChip(label: AppLocalizations.of(context)!.auth_tab_register, active: !isLogin, onTap: () {
            AnalyticsService.authTabSwitched('register');
            onToggle(false);
          }),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? OBColors.pink : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Shared field widgets ───────────────────────────────────────────────────────

class _OBTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final VoidCallback? onToggleObscure;
  final VoidCallback? onEditingComplete;

  const _OBTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.autofillHints,
    this.validator,
    this.onToggleObscure,
    this.onEditingComplete,
  });

  @override
  State<_OBTextField> createState() => _OBTextFieldState();
}

class _OBTextFieldState extends State<_OBTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscure,
      autofillHints: widget.autofillHints,
      onEditingComplete: widget.onEditingComplete,
      validator: widget.validator,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(
          color: _focused ? OBColors.pink : AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(
          widget.icon,
          color: _focused ? OBColors.pink : AppColors.textMuted,
          size: 20,
        ),
        suffixIcon: widget.onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  widget.obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: widget.onToggleObscure,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OBColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OBColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OBColors.pink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentOver, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentOver, width: 2),
        ),
        errorStyle: const TextStyle(
          color: AppColors.accentOver,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          gradient: onTap != null && !loading ? OBColors.gradient : null,
          color: onTap == null || loading ? OBColors.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null && !loading ? OBColors.buttonShadow : [],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Login form ─────────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({super.key});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    AnalyticsService.loginAttempted('email');
    try {
      final resp = await apiDio.post(
        '/api/v1/auth/login',
        data: {
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      await secureTokenStorage.saveTokens(TokenPair(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresAt: DateTime.now(), // unknown — trigger immediate refresh
      ));
      AnalyticsService.loginSuccess('email');
      await _afterLogin();
    } on DioException catch (e) {
      final reason = _extractDetail(e);
      AnalyticsService.loginFailed('email', reason);
      _showError(reason);
    } catch (e) {
      AnalyticsService.loginFailed('email', '$e');
      _showError('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _afterLogin() async {
    final token = await secureTokenStorage.loadAccessToken();
    if (token == null || !mounted) return;
    final hadPending = await syncOnboardingPending();
    final showReview = await markOnboardingDone(ref);
    if (!mounted) return;
    if (hadPending) {
      // User just finished onboarding and saw the plan there — do NOT redirect
      // to /way-to-goal (caused duplicate "Your plan is ready" screens).
      // Only invalidate caches so the dashboard reflects fresh server data.
      ref.invalidate(calculationResultProvider);
      ref.invalidate(todayStatsProvider);
    }
    await ref.read(authNotifierProvider.notifier).refreshUser();
    AnalyticsService.setUserId(_emailCtrl.text.trim());
    AnalyticsService.setUserProfile(email: _emailCtrl.text.trim());
    // Navigate directly — ai-consent gate can race with showReviewPromptProvider
    // and intercept the router redirect before review-prompt fires.
    if (showReview && mounted) context.go('/review-prompt');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.accentOver,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OBTextField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => _validateEmail(v, l10n),
          ),
          const SizedBox(height: 14),
          _OBTextField(
            controller: _passwordCtrl,
            label: l10n.auth_field_password,
            icon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.done,
            obscure: _obscure,
            autofillHints: const [AutofillHints.password],
            onToggleObscure: () {
              AnalyticsService.passwordVisibilityToggled();
              setState(() => _obscure = !_obscure);
            },
            onEditingComplete: _submit,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.auth_err_enter_password;
              return null;
            },
          ),
          const SizedBox(height: 28),
          _GradientButton(
            label: l10n.auth_btn_login,
            loading: _loading,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Register form ──────────────────────────────────────────────────────────────

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({super.key});

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    AnalyticsService.registerAttempted();
    try {
      final body = <String, dynamic>{
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      };
      final username = _usernameCtrl.text.trim();
      if (username.isNotEmpty) body['username'] = username;

      final resp = await apiDio.post('/api/v1/auth/register', data: body);
      final data = resp.data as Map<String, dynamic>;
      await secureTokenStorage.saveTokens(TokenPair(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresAt: DateTime.now(), // unknown — trigger immediate refresh
      ));
      AnalyticsService.registerSuccess();
      await _afterLogin();
    } on DioException catch (e) {
      final reason = _extractDetail(e);
      AnalyticsService.registerFailed(reason);
      _showError(reason);
    } catch (e) {
      AnalyticsService.registerFailed('$e');
      _showError('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _afterLogin() async {
    final token = await secureTokenStorage.loadAccessToken();
    if (token == null || !mounted) return;
    final hadPending = await syncOnboardingPending();
    final showReview = await markOnboardingDone(ref);
    if (!mounted) return;
    if (hadPending) {
      // User just finished onboarding and saw the plan there — do NOT redirect
      // to /way-to-goal (caused duplicate "Your plan is ready" screens).
      // Only invalidate caches so the dashboard reflects fresh server data.
      ref.invalidate(calculationResultProvider);
      ref.invalidate(todayStatsProvider);
    }
    await ref.read(authNotifierProvider.notifier).refreshUser();
    AnalyticsService.setUserId(_emailCtrl.text.trim());
    AnalyticsService.setUserProfile(
      email: _emailCtrl.text.trim(),
      name: _usernameCtrl.text.trim().isNotEmpty ? _usernameCtrl.text.trim() : null,
    );
    // Navigate directly — ai-consent gate can race with showReviewPromptProvider
    // and intercept the router redirect before review-prompt fires.
    if (showReview && mounted) context.go('/review-prompt');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.accentOver,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OBTextField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => _validateEmail(v, l10n),
          ),
          const SizedBox(height: 14),
          _OBTextField(
            controller: _usernameCtrl,
            label: l10n.auth_field_name,
            icon: Icons.person_outline_rounded,
            autofillHints: const [AutofillHints.name],
            validator: (_) => null,
          ),
          const SizedBox(height: 14),
          _OBTextField(
            controller: _passwordCtrl,
            label: l10n.auth_field_password,
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            autofillHints: const [AutofillHints.newPassword],
            onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.auth_err_enter_password;
              if (v.length < 8) return l10n.auth_err_min_password;
              return null;
            },
          ),
          const SizedBox(height: 14),
          _OBTextField(
            controller: _confirmCtrl,
            label: l10n.auth_field_confirm_password,
            icon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.done,
            obscure: _obscureConfirm,
            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            onEditingComplete: _submit,
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.auth_err_confirm_password;
              if (v != _passwordCtrl.text) return l10n.auth_err_passwords_no_match;
              return null;
            },
          ),
          const SizedBox(height: 28),
          _GradientButton(
            label: l10n.auth_btn_register,
            loading: _loading,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────────

String? _validateEmail(String? v, AppLocalizations l10n) {
  if (v == null || v.trim().isEmpty) return l10n.auth_err_enter_email;
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!re.hasMatch(v.trim())) return l10n.auth_err_invalid_email;
  return null;
}

String _extractDetail(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) return first['msg']?.toString() ?? '$e';
      }
    }
  } catch (_) {}
  return e.message ?? '$e';
}

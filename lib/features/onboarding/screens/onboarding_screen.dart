import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/core/analytics/analytics_service.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/ai_consent/ai_consent_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/storage/onboarding_pending_storage.dart';
import '../../../router.dart';
import '../../../shared/models/calculation_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../body_form/body_form_prefs.dart';
import '../../body_form/screens/body_form_screen.dart';
import '../../reward/reward_prefs.dart';
import '../../reward/widgets/reward_step.dart';
import '../../way_to_goal/widgets/plan_result_view.dart';
import '../widgets/ob_gradient_button.dart';
import '../widgets/onboarding_scaffold.dart';

// ─── Step definitions ──────────────────────────────────────────────────────────
enum _Step {
  landing,
  health,
  diet,
  // ignore: constant_identifier_names
  food_restrictions,
  goals,
  age,
  height,
  gender,
  weight,
  training,
  // ignore: constant_identifier_names
  body_form,
  reward,
  // ignore: constant_identifier_names
  weight_loss_info,
  // ignore: constant_identifier_names
  weight_loss_speed,
  // ignore: constant_identifier_names
  info_1,
  // ignore: constant_identifier_names
  info_2,
  // ignore: constant_identifier_names
  info_3,
  method,
  reviews,
  result,
  auth,
}

const _ageOptions = [
  ('18–24', 21),
  ('25–34', 30),
  ('35–44', 40),
  ('45+', 50),
];

// Hero text outline — four hard 1.4-pixel offsets simulate a stroke, then a
// soft drop shadow lifts the text off the photo regardless of which area
// happens to land behind a given letter.
const List<Shadow> _kHeroTextShadows = [
  Shadow(color: Color(0xCC000000), offset: Offset(-1.4, 0)),
  Shadow(color: Color(0xCC000000), offset: Offset(1.4, 0)),
  Shadow(color: Color(0xCC000000), offset: Offset(0, -1.4)),
  Shadow(color: Color(0xCC000000), offset: Offset(0, 1.4)),
  Shadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 2)),
];

// ─── Calculation helpers ───────────────────────────────────────────────────────
double _getActivityCoef(String trainingFreq) {
  switch (trainingFreq) {
    case 'daily': return 1.725;
    case '3-4': return 1.55;
    case '1-2': return 1.375;
    default: return 1.2;
  }
}

CalculationResult _calcPreview({
  required int age,
  required double weight,
  required double height,
  required String gender,
  required String trainingDays,
  double? targetWeight,
  double weightLossSpeedKgPerWeek = 0.5,
}) {
  final offset = gender == 'male' ? 5.0 : -161.0;
  final bmr = 10 * weight + 6.25 * height - 5 * age + offset;
  final tdee = bmr * _getActivityCoef(trainingDays);
  final deficitPerDay = (weightLossSpeedKgPerWeek * 7700 / 7).clamp(100.0, 1100.0);
  final target = (tdee - deficitPerDay).clamp(1200.0, 9999.0);
  final protein = (weight * 1.6);
  final fat = (weight * 0.9);
  final carbs = ((target - protein * 4 - fat * 9) / 4).clamp(0.0, 9999.0);
  int? daysToGoal;
  if (targetWeight != null && targetWeight < weight) {
    final deficit = tdee - target;
    if (deficit > 0) {
      daysToGoal = ((weight - targetWeight) * 7700 / deficit).round();
    }
  }
  return CalculationResult(
    bmr: bmr,
    tdee: tdee,
    targetCalories: target,
    protein: protein,
    fat: fat,
    carbs: carbs,
    daysToGoal: daysToGoal,
    targetWeight: targetWeight,
  );
}

// ─── Main screen ───────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // ── Dynamic step tracking ────────────────────────────────────────────────────
  int _stepIndex = 0;

  List<_Step> _buildStepList() {
    return [
      _Step.landing,
      _Step.health,
      _Step.diet,
      _Step.food_restrictions,
      _Step.goals,
      _Step.age,
      _Step.height,
      _Step.gender,
      _Step.weight,
      _Step.training,
      _Step.body_form,
      _Step.reward,
      if (_goals.contains('lose_weight')) _Step.weight_loss_info,
      if (_goals.contains('lose_weight')) _Step.weight_loss_speed,
      _Step.info_1,
      _Step.info_2,
      _Step.info_3,
      // _Step.method removed (manual QA: «как добавить еду» screen вырезан)
      _Step.reviews,
      _Step.result,
      _Step.auth,
    ];
  }

  _Step get _currentStep => _buildStepList()[_stepIndex];

  // ── Data ─────────────────────────────────────────────────────────────────────
  int? _age;
  double? _height;
  String _gender = '';
  double? _weight;
  double? _targetWeight;
  String _trainingFreq = '';
  int? _bodyFormCurrent;
  int? _bodyFormDesired;
  String? _reward;

  // New step data
  Set<String> _healthConditions = {'none'};
  String _dietType = 'none';
  String _foodRestrictions = '';
  Set<String> _goals = {};
  double _weightLossSpeedKgPerWeek = 0.5;

  // Controllers
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String? _error;
  bool _showSkipDialog = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.onboardingStarted();
    AnalyticsService.onboardingStepViewed(_Step.landing.name);
    _restoreProgress();
  }

  /// Restore step index and answers from SharedPreferences after a kill-restore.
  /// UC5: if `onboarding_current_step` key exists, resume from that step.
  Future<void> _restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStepName = prefs.getString('onboarding_current_step');
      final savedAnswersJson = prefs.getString('onboarding_answers');

      if (savedStepName == null) return;

      // Try to find the saved step in the enum.
      final savedStep = _Step.values.where((s) => s.name == savedStepName).firstOrNull;
      if (savedStep == null) return;

      // Restore answers from JSON if available.
      if (savedAnswersJson != null) {
        try {
          final answers = jsonDecode(savedAnswersJson) as Map<String, dynamic>;
          _restoreAnswers(answers);
        } catch (_) {
          // Corrupted answers — start with defaults, still resume step.
        }
      }

      // Restore body-form selection (separate SharedPrefs keys).
      final savedBodyForm = await BodyFormPrefs.load();
      final savedReward = await RewardPrefs.load();

      // Find the step index in the current step list.
      final steps = _buildStepList();
      final restoredIndex = steps.indexOf(savedStep);
      if (mounted) {
        setState(() {
          if (restoredIndex > 0) {
            _stepIndex = restoredIndex;
          }
          if (savedBodyForm != null) {
            _bodyFormCurrent = savedBodyForm.current;
            _bodyFormDesired = savedBodyForm.desired;
          }
          if (savedReward != null) {
            _reward = savedReward;
          }
        });
      }
    } catch (_) {
      // If restoration fails for any reason, just start from the beginning.
    }
  }

  /// Populate data fields from a previously serialised answers map.
  void _restoreAnswers(Map<String, dynamic> answers) {
    _age = answers['age'] as int?;
    _height = (answers['height'] as num?)?.toDouble();
    _gender = answers['gender'] as String? ?? '';
    _weight = (answers['weight'] as num?)?.toDouble();
    _targetWeight = (answers['targetWeight'] as num?)?.toDouble();
    _trainingFreq = answers['trainingFreq'] as String? ?? '';
    _dietType = answers['dietType'] as String? ?? 'none';
    _foodRestrictions = answers['foodRestrictions'] as String? ?? '';

    final healthList = answers['healthConditions'];
    if (healthList is List) {
      _healthConditions = healthList.cast<String>().toSet();
    }
    final goalsList = answers['goals'];
    if (goalsList is List) {
      _goals = goalsList.cast<String>().toSet();
    }

    // Restore text controller values.
    if (_height != null) _heightCtrl.text = _height!.toStringAsFixed(0);
    if (_weight != null) _weightCtrl.text = _weight!.toStringAsFixed(0);
  }

  /// Persist current step name and all answers to SharedPreferences.
  /// Called after each successful _goNext so kill-restore can resume here.
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding_current_step', _currentStep.name);
      await prefs.setString(
        'onboarding_answers',
        jsonEncode({
          'age': _age,
          'height': _height,
          'gender': _gender,
          'weight': _weight,
          'targetWeight': _targetWeight,
          'trainingFreq': _trainingFreq,
          'dietType': _dietType,
          'foodRestrictions': _foodRestrictions,
          'healthConditions': _healthConditions.toList(),
          'goals': _goals.toList(),
        }),
      );
    } catch (_) {
      // Non-critical — if save fails, user just restarts from beginning.
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _goNext() {
    AnalyticsService.onboardingStepCompleted(_currentStep.name);
    final steps = _buildStepList();
    setState(() {
      _error = null;
      _showSkipDialog = false;
      if (_stepIndex < steps.length - 1) {
        _stepIndex++;
        AnalyticsService.onboardingStepViewed(_buildStepList()[_stepIndex].name);
      }
    });
    // UC5: persist progress so kill-restore can resume from here.
    _saveProgress();
  }

  void _goBack() {
    AnalyticsService.onboardingBackTapped(_currentStep.name);
    setState(() {
      _error = null;
      _showSkipDialog = false;
      if (_stepIndex > 0) _stepIndex--;
    });
  }

  void _savePending() {
    OnboardingPendingStorage.save(OnboardingPendingData(
      age: _age,
      height: _height,
      gender: _gender.isEmpty ? null : _gender,
      weight: _weight,
      targetWeight: _targetWeight,
      trainingDays: _trainingFreq,
      healthConditions: _healthConditions.toList(),
      dietType: _dietType,
      foodRestrictions: _foodRestrictions.isNotEmpty ? _foodRestrictions : null,
      goals: _goals.toList(),
    ));
  }

  // ── Step handlers ───────────────────────────────────────────────────────────
  void _handleAgeSelect(int age) {
    _age = age;
    AnalyticsService.onboardingAgeSelected(age);
    _savePending();
    _goNext();
  }

  void _handleHeightNext(AppLocalizations l10n) {
    final h = double.tryParse(_heightCtrl.text);
    if (h == null || h < 100 || h > 250) {
      setState(() => _error = l10n.ob_err_height);
      return;
    }
    _height = h;
    AnalyticsService.onboardingHeightEntered(h.toInt());
    _savePending();
    _goNext();
  }

  void _handleGenderSelect(String g) {
    _gender = g;
    AnalyticsService.onboardingGenderSelected(g);
    _savePending();
    _goNext();
  }

  void _handleWeightNext(AppLocalizations l10n) {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null || w < 30 || w > 300) {
      setState(() => _error = l10n.ob_err_weight);
      return;
    }
    _weight = w;
    AnalyticsService.onboardingWeightEntered(w.toInt(), w.toInt());
    _savePending();
    _goNext();
  }

  void _handleTrainingNext(AppLocalizations l10n) {
    if (_trainingFreq.isEmpty) {
      setState(() => _error = l10n.ob_err_training);
      return;
    }
    final daysCount = _trainingFreq == '0' ? 0 : _trainingFreq == '1-2' ? 2 : _trainingFreq == '3-4' ? 4 : 7;
    AnalyticsService.onboardingTrainingDaysSelected(daysCount);
    _savePending();
    _goNext();
  }

  void _handleTrainingSelect(String value) {
    setState(() => _trainingFreq = value);
  }

  void _handleRewardSelected(String value) {
    setState(() => _reward = value);
    unawaited(RewardPrefs.save(value));
    _savePending();
  }

  void _handleBodyFormCompleted(
    int currentIdx,
    int desiredIdx,
    double? calcTargetWeight,
  ) {
    setState(() {
      _bodyFormCurrent = currentIdx;
      _bodyFormDesired = desiredIdx;
      // Target weight comes from body form only for lose_weight goal.
      // Muscle-gain / maintain goals → recomposition → no weight graph.
      _targetWeight =
          _goals.contains('lose_weight') ? calcTargetWeight : null;
    });
    _savePending();
    _goNext();
  }

  Future<void> _navigateToLogin() async {
    // Explicit await-save with all collected data before leaving onboarding.
    await OnboardingPendingStorage.save(OnboardingPendingData(
      age: _age,
      height: _height,
      gender: _gender.isEmpty ? null : _gender,
      weight: _weight,
      targetWeight: _targetWeight,
      trainingDays: _trainingFreq,
      healthConditions: _healthConditions.toList(),
      dietType: _dietType,
      foodRestrictions: _foodRestrictions.isNotEmpty ? _foodRestrictions : null,
      goals: _goals.toList(),
    ));
    AnalyticsService.onboardingCompleted();
    AnalyticsService.onboardingGoToLogin();
    AnalyticsService.setUserProfile(
      gender: _gender.isNotEmpty ? _gender : null,
      age: _age,
    );
    // iOS keeps the Keychain auth token across app reinstalls while
    // SharedPreferences (onboarding_done) is wiped. Without clearing auth
    // state first, the router sees isLoggedIn=true + onboarding_done=false and
    // bounces /login → /journal-v2 → /onboarding, re-rendering THIS step's
    // spinner — an infinite redirect loop (the "eternal loading" after the plan
    // screen). Logging out first makes the redirect chain land cleanly on
    // /login. Mirrors the landing "I already have an account" path, which
    // already documents and fixes this exact bounce.
    if (mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
    if (mounted) context.go('/login');
  }

  // ── Result calculation ──────────────────────────────────────────────────────
  CalculationResult get _preview => _calcPreview(
        age: _age ?? 30,
        weight: _weight ?? 65,
        height: _height ?? 165,
        gender: _gender.isEmpty ? 'female' : _gender,
        trainingDays: _trainingFreq,
        targetWeight: _targetWeight,
        weightLossSpeedKgPerWeek: _goals.contains('lose_weight') ? _weightLossSpeedKgPerWeek : 0.5,
      );

  // ── Progress ────────────────────────────────────────────────────────────────
  bool get _canSkip => _stepIndex >= 1 && _stepIndex <= 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLanding = _currentStep == _Step.landing;

    // Landing step manages its own layout (full-screen gradient header + CTA).
    if (isLanding) {
      return Scaffold(
        backgroundColor: OBColors.bg,
        body: Stack(
          children: [
            _buildStepContent(l10n),
            if (_showSkipDialog) _buildSkipDialog(l10n),
          ],
        ),
      );
    }

    // All other steps use OnboardingScaffold so the CTA lives in
    // bottomNavigationBar — Flutter automatically shifts it above the keyboard.
    final footer = _buildFooter(l10n);
    return Stack(
      children: [
        OnboardingScaffold(
          header: _buildHeader(l10n),
          body: _buildStepContent(l10n),
          primaryCta: footer.primaryCta,
          secondaryCta: footer.secondaryCta,
        ),
        if (_showSkipDialog) _buildSkipDialog(l10n),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l10n) {
    final steps = _buildStepList();
    final progress = (_stepIndex + 1) / steps.length;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _goBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppShadow.sm,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  color: OBColors.pink,
                  backgroundColor: OBColors.border,
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_canSkip)
              GestureDetector(
                onTap: () => setState(() => _showSkipDialog = true),
                child: Text(
                  l10n.ob_skip_btn,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              )
            else
              const SizedBox(width: 50),
          ],
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────
  /// Returns [_FooterCtaData] — the primary CTA widget and an optional
  /// secondary CTA — for the current step.
  ///
  /// These are placed into [OnboardingScaffold.primaryCta] /
  /// [OnboardingScaffold.secondaryCta], which live in [bottomNavigationBar].
  /// Flutter therefore shifts them above the keyboard automatically.
  _FooterCtaData _buildFooter(AppLocalizations l10n) {
    final isRu = ref.watch(localeProvider).languageCode == 'ru';
    final nextLabel = isRu ? 'Далее' : 'Next';

    switch (_currentStep) {
      // Landing and auth are excluded: landing owns its CTA; auth auto-navigates.
      case _Step.landing:
      case _Step.auth:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: nextLabel, onTap: _goNext),
        );

      case _Step.health:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _healthConditions.isNotEmpty ? _goNext : null,
          ),
        );

      case _Step.diet:
        // Tap-on-card already calls _goNext; the explicit button is added so
        // the user always sees a visible CTA (§3.4 of the spec).
        // Diet default value is 'none' so the button is enabled from the start.
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _dietType.isNotEmpty ? _goNext : null,
          ),
        );

      case _Step.food_restrictions:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: nextLabel, onTap: _goNext),
          secondaryCta: TextButton(
            onPressed: () {
              setState(() => _foodRestrictions = '');
              _goNext();
            },
            child: Text(
              isRu ? 'Пропустить' : 'Skip',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        );

      case _Step.goals:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _goals.isNotEmpty ? _goNext : null,
          ),
        );

      case _Step.age:
        // Tap-on-card already calls _goNext; the explicit button is added for
        // visibility (§3.4).
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _age != null ? _goNext : null,
          ),
        );

      case _Step.height:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: l10n.common_next,
            onTap: _heightCtrl.text.isEmpty
                ? null
                : () => _handleHeightNext(l10n),
          ),
        );

      case _Step.gender:
        // Tap-on-card already calls _goNext; the explicit button is added for
        // visibility (§3.4).
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _gender.isNotEmpty ? _goNext : null,
          ),
        );

      case _Step.weight:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: l10n.ob_footer_calc,
            onTap: _weightCtrl.text.isEmpty
                ? null
                : () => _handleWeightNext(l10n),
          ),
        );

      case _Step.training:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: l10n.common_next,
            onTap: _trainingFreq.isEmpty
                ? null
                : () => _handleTrainingNext(l10n),
          ),
        );

      case _Step.body_form:
        // BodyFormScreen renders its own buttons — no scaffold-level CTA.
        return const _FooterCtaData(primaryCta: SizedBox.shrink());

      case _Step.reward:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: nextLabel,
            onTap: _reward == null ? null : _goNext,
          ),
          secondaryCta: TextButton(
            onPressed: () {
              setState(() => _reward = null);
              _goNext();
            },
            child: Text(
              isRu ? 'Пропустить' : 'Skip',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        );

      case _Step.weight_loss_info:
      case _Step.info_1:
      case _Step.info_2:
      case _Step.info_3:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: nextLabel, onTap: _goNext),
        );

      case _Step.weight_loss_speed:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: nextLabel, onTap: _goNext),
        );

      case _Step.reviews:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: nextLabel, onTap: _goNext),
        );

      case _Step.method:
        return _FooterCtaData(
          primaryCta: ObGradientButton(label: l10n.common_next, onTap: _goNext),
        );

      case _Step.result:
        return _FooterCtaData(
          primaryCta: ObGradientButton(
            label: l10n.ob_footer_login,
            onTap: _goNext,
          ),
        );
    }
  }

  // ── Step content ─────────────────────────────────────────────────────────────
  Widget _buildStepContent(AppLocalizations l10n) {
    final isRu = ref.watch(localeProvider).languageCode == 'ru';

    switch (_currentStep) {
      case _Step.landing:
        return _LandingStep(
          l10n: l10n,
          onNext: _goNext,
          // iOS keeps Keychain across app uninstalls, so a stale auth token
          // can survive a reinstall while SharedPreferences is wiped. If we
          // call context.go('/login') directly, the router sees isLoggedIn=true
          // → bounces to /journal-v2 → bounces back to /onboarding (because
          // onboarding_done=false). User ends up where they started. Clearing
          // auth state first makes the redirect chain land cleanly on /login.
          onLogin: () async {
            await ref.read(authNotifierProvider.notifier).logout();
            if (mounted) context.go('/login');
          },
          locale: ref.watch(localeProvider),
          onLocaleChange: (loc) => ref.read(localeProvider.notifier).setLocale(loc),
          onboardingDone: ref.watch(onboardingDoneProvider),
        );

      case _Step.health:
        return _HealthStep(
          value: _healthConditions,
          onChange: (v) => setState(() => _healthConditions = v),
          isRu: isRu,
        );

      case _Step.diet:
        return _DietStep(
          value: _dietType,
          onChange: (v) {
            setState(() => _dietType = v);
            _goNext();
          },
          isRu: isRu,
        );

      case _Step.food_restrictions:
        return _FoodRestrictionsStep(
          value: _foodRestrictions,
          onChange: (v) => setState(() => _foodRestrictions = v),
          isRu: isRu,
        );

      case _Step.goals:
        return _GoalsStep(
          value: _goals,
          onChange: (v) {
            setState(() => _goals = v);
            _savePending();
          },
          isRu: isRu,
        );

      case _Step.age:
        return _AgeStep(l10n: l10n, selected: _age, onSelect: _handleAgeSelect);

      case _Step.height:
        return _HeightStep(
          l10n: l10n,
          controller: _heightCtrl,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
        );

      case _Step.gender:
        return _GenderStep(l10n: l10n, selected: _gender, onSelect: _handleGenderSelect);

      case _Step.weight:
        return _WeightStep(
          l10n: l10n,
          weightCtrl: _weightCtrl,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
        );

      case _Step.training:
        return _TrainingStep(
          l10n: l10n,
          selected: _trainingFreq,
          onSelect: _handleTrainingSelect,
          error: _error,
        );

      case _Step.body_form:
        return BodyFormScreen(
          isOnboarding: true,
          gender: _gender,
          initialCurrent: _bodyFormCurrent ?? 0,
          initialDesired: _bodyFormDesired ?? 0,
          currentWeight: _weight,
          onCompleted: _handleBodyFormCompleted,
        );

      case _Step.reward:
        return RewardStep(
          value: _reward,
          onChange: _handleRewardSelected,
          isRu: isRu,
        );

      case _Step.weight_loss_info:
        return _WeightLossInfoStep(isRu: isRu);

      case _Step.weight_loss_speed:
        return _WeightLossSpeedStep(
          speedKgPerWeek: _weightLossSpeedKgPerWeek,
          onChanged: (v) => setState(() => _weightLossSpeedKgPerWeek = v),
          currentWeight: _weight ?? 70,
          targetWeight: _targetWeight ?? (_weight != null ? _weight! - 5 : 65),
          isRu: isRu,
        );

      case _Step.info_1:
        return _InfoStep(
          icon: Icons.center_focus_strong_rounded,
          iconColor: const Color(0xFF16A34A),
          titleRu: 'Распознаём точнее',
          titleEn: 'More accurate recognition',
          subtitleRu: 'Наш алгоритм анализирует форму, текстуру и цвет блюда',
          subtitleEn: 'Our algorithm analyzes shape, texture and color of the dish',
          features: [
            _InfoFeature(icon: Icons.photo_camera_rounded, textRu: 'ИИ-распознавание еды по фото', textEn: 'AI-powered food photo recognition'),
            _InfoFeature(icon: Icons.record_voice_over_rounded, textRu: 'Голосовой ввод — скажи что съел', textEn: 'Voice input — just say what you ate'),
            _InfoFeature(icon: Icons.edit_rounded, textRu: 'Текстовый ввод с умными подсказками', textEn: 'Text input with smart suggestions'),
          ],
          isRu: isRu,
        );

      case _Step.info_2:
        return _InfoStep(
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFF3B82F6),
          titleRu: 'Основано на науке',
          titleEn: 'Science-based approach',
          subtitleRu: 'Расчёты по международным стандартам питания',
          subtitleEn: 'Calculations based on international nutrition standards',
          features: [
            _InfoFeature(icon: Icons.calculate_rounded, textRu: 'Формула Миффлина-Сент-Жора', textEn: 'Mifflin-St Jeor formula'),
            _InfoFeature(icon: Icons.storage_rounded, textRu: 'База USDA — 500 000+ продуктов', textEn: 'USDA database — 500 000+ products'),
            _InfoFeature(icon: Icons.fitness_center_rounded, textRu: 'Учёт уровня активности и метаболизма', textEn: 'Activity level and metabolism accounted for'),
          ],
          isRu: isRu,
        );

      case _Step.info_3:
        return _InfoStep(
          icon: Icons.psychology_rounded,
          iconColor: const Color(0xFF8B5CF6),
          titleRu: 'Нутрициолог в кармане',
          titleEn: 'Your pocket nutritionist',
          subtitleRu: 'ИИ-помощник по питанию доступен 24/7',
          subtitleEn: 'AI nutrition assistant available 24/7',
          features: [
            _InfoFeature(icon: Icons.chat_bubble_rounded, textRu: 'Персональные рекомендации в чате', textEn: 'Personalized recommendations in chat'),
            _InfoFeature(icon: Icons.trending_down_rounded, textRu: 'Анализ рациона и прогресса', textEn: 'Diet and progress analysis'),
            _InfoFeature(icon: Icons.star_rounded, textRu: 'Бесплатно — без ограничений', textEn: 'Free — without limits'),
          ],
          isRu: isRu,
        );

      case _Step.method:
        return _MethodStep(l10n: l10n);

      case _Step.reviews:
        return _ReviewsStep(isRu: isRu);

      case _Step.result:
        return _ResultStep(
          l10n: l10n,
          preview: _preview,
          currentWeight: _weight,
        );

      case _Step.auth:
        // Auto-navigate to login
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToLogin());
        return const Center(child: CircularProgressIndicator(color: OBColors.pink));
    }
  }

  // ── Skip dialog ─────────────────────────────────────────────────────────────
  Widget _buildSkipDialog(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => setState(() => _showSkipDialog = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.ob_skip_title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      decoration: TextDecoration.none,
                    )),
                const SizedBox(height: 8),
                Text(l10n.ob_skip_sub,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _showSkipDialog = false);
                      _goNext();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: OBColors.pink),
                    child: Text(l10n.ob_skip_continue),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => _showSkipDialog = false),
                  child: Text(l10n.ob_skip_back,
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Landing ───────────────────────────────────────────────────────────
class _LandingStep extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChange;
  final bool onboardingDone;

  const _LandingStep({
    required this.l10n,
    required this.onNext,
    required this.onLogin,
    required this.locale,
    required this.onLocaleChange,
    required this.onboardingDone,
  });

  @override
  Widget build(BuildContext context) {
    final isRu = locale.languageCode == 'ru';

    final heroHeight = MediaQuery.of(context).size.height * 0.44;

    return Column(
      children: [
        // Hero header — landing photo fills the top half of the screen;
        // title + subtitle overlay the bottom of the photo.
        SizedBox(
          height: heroHeight,
          width: double.infinity,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background photo. cover keeps aspect ratio and crops
                // horizontally — the girl stays visible because she is
                // close to centre; some of the left wall + right food bowl
                // may be trimmed on tall screens.
                Image.asset(
                  'assets/onboarding/landing_hero.jpg',
                  fit: BoxFit.cover,
                  // Bias the visible window toward the right side of the
                  // image so the phone + meal-scan card stay in frame; the
                  // far-left wall background gets cropped instead.
                  alignment: const Alignment(0.3, 0),
                ),
                // Bottom gradient for text legibility.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Language toggle pinned to the top-right under the status bar.
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _LangToggle(isRu: isRu, onToggle: onLocaleChange),
                    ),
                  ),
                ),
                // Title + subtitle pinned to the bottom-left of the hero.
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${l10n.ob_landing_title1} ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  shadows: _kHeroTextShadows,
                                ),
                              ),
                              TextSpan(
                                text: l10n.ob_landing_title2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -1,
                                  fontStyle: FontStyle.italic,
                                  shadows: _kHeroTextShadows,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.ob_landing_sub,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                            shadows: _kHeroTextShadows,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Features — scrollable so the 4th tile is never clipped under the
        // sticky CTA on shorter devices (hero + CTA can squeeze the middle).
        // Bottom padding keeps the last tile clear of the button.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                _FeatureTile(icon: Icons.photo_camera_rounded, text: l10n.ob_demo_perk1),
                const SizedBox(height: 16),
                _FeatureTile(icon: Icons.mic_rounded, text: l10n.ob_demo_perk2),
                const SizedBox(height: 16),
                _FeatureTile(icon: Icons.bar_chart_rounded, text: l10n.ob_demo_perk3),
                const SizedBox(height: 16),
                _FeatureTile(icon: Icons.smart_toy_rounded, text: l10n.ob_demo_perk4),
              ],
            ),
          ),
        ),
        // CTA
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                _GradientButton(label: l10n.ob_landing_cta, onTap: onNext),
                // "I already have an account" — always shown so first-time
                // users with an existing account can skip the entire onboarding
                // flow and go straight to login. Previously gated behind
                // `onboardingDone` which meant only returning users (who'd
                // already finished onboarding once) saw it — the exact users
                // who didn't need it. Inverted: first-timers benefit most.
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () {
                      debugPrint('[onboarding] "already have account" tapped');
                      onLogin();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: OBColors.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)!.ob_already_account,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: OBColors.pink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!onboardingDone) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.ob_landing_cta_sub1} — ${l10n.ob_landing_cta_sub2}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LangToggle extends StatelessWidget {
  final bool isRu;
  final ValueChanged<Locale> onToggle;

  const _LangToggle({required this.isRu, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Dark pill + thin white border so both chips stay legible over the
      // bright hero photo (the old white@20% pill was nearly invisible).
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(label: 'RU', active: isRu, onTap: () => onToggle(const Locale('ru'))),
          _Chip(label: 'EN', active: !isRu, onTap: () => onToggle(const Locale('en'))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: OBColors.pinkSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: OBColors.pink, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: AppColors.text, height: 1.3),
          ),
        ),
      ],
    );
  }
}

// ─── Health step ───────────────────────────────────────────────────────────────
class _HealthStep extends StatelessWidget {
  final Set<String> value;
  final ValueChanged<Set<String>> onChange;
  final bool isRu;

  const _HealthStep({
    required this.value,
    required this.onChange,
    required this.isRu,
  });

  static const _options = <(String, IconData, String, String)>[
    ('none', Icons.check_circle_outline_rounded, 'Нет ограничений', 'No restrictions'),
    ('diabetes', Icons.water_drop_rounded, 'Диабет', 'Diabetes'),
    ('hypertension', Icons.favorite_rounded, 'Гипертония', 'Hypertension'),
    ('celiac', Icons.grass_rounded, 'Целиакия', 'Celiac disease'),
    ('lactose', Icons.local_drink_rounded, 'Непереносимость лактозы', 'Lactose intolerance'),
    ('kidney', Icons.healing_rounded, 'Болезни почек', 'Kidney disease'),
    ('heart', Icons.monitor_heart_rounded, 'Болезни сердца', 'Heart disease'),
    ('allergies', Icons.eco_rounded, 'Аллергии', 'Allergies'),
  ];

  void _toggle(String id) {
    final updated = Set<String>.from(value);
    if (id == 'none') {
      updated
        ..clear()
        ..add('none');
    } else {
      updated.remove('none');
      if (updated.contains(id)) {
        updated.remove(id);
        if (updated.isEmpty) updated.add('none');
      } else {
        updated.add(id);
      }
    }
    onChange(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRu ? 'Есть ли у тебя ограничения по здоровью?' : 'Any health conditions?',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isRu ? 'Это поможет составить безопасный план питания' : 'This helps us create a safe nutrition plan',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRu
                        ? 'Приложение не заменяет консультацию врача. При наличии заболеваний проконсультируйтесь со специалистом перед изменением рациона.'
                        : 'This app does not replace professional medical advice. If you have any health conditions, consult a healthcare professional before changing your diet.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._options.map((opt) {
            final isSelected = value.contains(opt.$1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _toggle(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? OBColors.pinkSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? OBColors.pink : OBColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(opt.$2, size: 20, color: isSelected ? OBColors.pink : AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isRu ? opt.$3 : opt.$4,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? OBColors.pink : AppColors.text,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? OBColors.pink : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? OBColors.pink : OBColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Diet step ─────────────────────────────────────────────────────────────────
class _DietStep extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final bool isRu;

  const _DietStep({
    required this.value,
    required this.onChange,
    required this.isRu,
  });

  static const _options = <(String, IconData, String, String)>[
    ('none', Icons.restaurant_rounded, 'Обычная', 'No specific diet'),
    ('vegetarian', Icons.eco_rounded, 'Вегетарианство', 'Vegetarian'),
    ('vegan', Icons.spa_rounded, 'Веганство', 'Vegan'),
    ('keto', Icons.local_fire_department_rounded, 'Кето', 'Keto'),
    ('paleo', Icons.set_meal_rounded, 'Палео', 'Paleo'),
    ('mediterranean', Icons.water_rounded, 'Средиземноморская', 'Mediterranean'),
    ('halal', Icons.star_rounded, 'Халяль', 'Halal'),
    ('kosher', Icons.star_border_rounded, 'Кошерная', 'Kosher'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRu ? 'Придерживаешься какой-либо диеты?' : 'Do you follow a specific diet?',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isRu ? 'Выбери один вариант' : 'Choose one option',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          ..._options.map((opt) {
            final isSelected = value == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onChange(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? OBColors.pinkSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? OBColors.pink : OBColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(opt.$2, size: 20, color: isSelected ? OBColors.pink : AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isRu ? opt.$3 : opt.$4,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? OBColors.pink : AppColors.text,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? OBColors.pink : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? OBColors.pink : OBColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Food restrictions step ────────────────────────────────────────────────────
class _FoodRestrictionsStep extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final bool isRu;

  const _FoodRestrictionsStep({
    required this.value,
    required this.onChange,
    required this.isRu,
  });

  @override
  State<_FoodRestrictionsStep> createState() => _FoodRestrictionsStepState();
}

class _FoodRestrictionsStepState extends State<_FoodRestrictionsStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRu = widget.isRu;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRu ? 'Есть нелюбимые или запрещённые продукты?' : 'Any foods you avoid?',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isRu ? 'Необязательно — пропусти, если нет' : 'Optional — skip if none',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            autofocus: false,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: isRu
                  ? 'Орехи, морепродукты, глютен...'
                  : 'Nuts, seafood, gluten...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: OBColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: OBColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: OBColors.pink, width: 2),
              ),
            ),
            onChanged: widget.onChange,
          ),
        ],
      ),
    );
  }
}

// ─── Goals step ────────────────────────────────────────────────────────────────
class _GoalsStep extends StatelessWidget {
  final Set<String> value;
  final ValueChanged<Set<String>> onChange;
  final bool isRu;

  const _GoalsStep({
    required this.value,
    required this.onChange,
    required this.isRu,
  });

  static const _options = <(String, IconData, String, String)>[
    ('lose_weight', Icons.monitor_weight_rounded, 'Похудеть', 'Lose weight'),
    ('maintain_weight', Icons.track_changes_rounded, 'Поддерживать вес', 'Maintain weight'),
    ('gain_muscle', Icons.fitness_center_rounded, 'Набирать мышечную массу', 'Build muscle'),
    ('stay_toned', Icons.flash_on_rounded, 'Быть в тонусе', 'Stay toned'),
    ('maintain_glucose', Icons.water_drop_rounded, 'Поддерживать уровень глюкозы', 'Maintain glucose'),
    ('maintain_energy', Icons.bolt_rounded, 'Высокий уровень энергии', 'High energy all day'),
    ('mental_clarity', Icons.psychology_rounded, 'Ясность разума', 'Mental clarity'),
  ];

  void _toggle(String id) {
    final updated = Set<String>.from(value);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    onChange(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRu ? 'Какова твоя цель?' : "What's your goal?",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isRu ? 'Можно выбрать несколько' : 'Choose one or more',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          ..._options.map((opt) {
            final isSelected = value.contains(opt.$1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _toggle(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? OBColors.pinkSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? OBColors.pink : OBColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(opt.$2, size: 20, color: isSelected ? OBColors.pink : AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isRu ? opt.$3 : opt.$4,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? OBColors.pink : AppColors.text,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? OBColors.pink : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? OBColors.pink : OBColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Step: Age ─────────────────────────────────────────────────────────────────
class _AgeStep extends StatelessWidget {
  final AppLocalizations l10n;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _AgeStep({required this.l10n, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: l10n.ob_step_age_title,
      hint: l10n.ob_step_age_hint,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
        physics: const NeverScrollableScrollPhysics(),
        children: _ageOptions.map((opt) {
          final isSelected = selected == opt.$2;
          return _OptionButton(
            label: opt.$1,
            selected: isSelected,
            onTap: () => onSelect(opt.$2),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Step: Height ──────────────────────────────────────────────────────────────
class _HeightStep extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;

  const _HeightStep({
    required this.l10n,
    required this.controller,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: l10n.ob_step_height_title,
      hint: l10n.ob_step_height_hint,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.text),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: '170',
                    hintStyle: TextStyle(fontSize: 48, color: AppColors.border),
                  ),
                  onChanged: onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.ob_step_height_unit,
                  style: const TextStyle(fontSize: 18, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppColors.accentOver, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ─── Step: Gender ──────────────────────────────────────────────────────────────
class _GenderStep extends StatelessWidget {
  final AppLocalizations l10n;
  final String selected;
  final ValueChanged<String> onSelect;

  const _GenderStep({required this.l10n, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: l10n.ob_step_gender_title,
      hint: l10n.ob_step_gender_hint,
      child: Row(
        children: [
          Expanded(
            child: _OptionButton(
              label: l10n.ob_step_gender_female,
              selected: selected == 'female',
              onTap: () => onSelect('female'),
              height: 80,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _OptionButton(
              label: l10n.ob_step_gender_male,
              selected: selected == 'male',
              onTap: () => onSelect('male'),
              height: 80,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step: Weight ──────────────────────────────────────────────────────────────
class _WeightStep extends StatelessWidget {
  final AppLocalizations l10n;
  final TextEditingController weightCtrl;
  final String? error;
  final ValueChanged<String> onChanged;

  const _WeightStep({
    required this.l10n,
    required this.weightCtrl,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: l10n.ob_step_weight_title,
      hint: l10n.ob_step_weight_hint,
      child: Column(
        children: [
          _WeightCard(
            label: l10n.ob_step_weight_now,
            controller: weightCtrl,
            autofocus: true,
            onChanged: onChanged,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: AppColors.accentOver, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  const _WeightCard({
    required this.label,
    required this.controller,
    required this.autofocus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: '70',
              hintStyle: const TextStyle(fontSize: 32, color: AppColors.border),
              suffixText: AppLocalizations.of(context)!.ob_weight_unit,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Step: Training frequency ──────────────────────────────────────────────────
class _TrainingStep extends StatelessWidget {
  final AppLocalizations l10n;
  final String selected;
  final ValueChanged<String> onSelect;
  final String? error;

  const _TrainingStep({
    required this.l10n,
    required this.selected,
    required this.onSelect,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('0', l10n.ob_training_0),
      ('1-2', l10n.ob_training_1_2),
      ('3-4', l10n.ob_training_3_4),
      ('daily', l10n.ob_training_daily),
    ];

    return _StepScaffold(
      title: l10n.ob_step_training_title,
      hint: l10n.ob_step_training_sub,
      child: Column(
        children: [
          ...options.map((opt) {
            final isSelected = selected == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onSelect(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? OBColors.pinkSoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected ? OBColors.pink : OBColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? OBColors.pink : AppColors.text,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: OBColors.pink, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.accentOver, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Weight loss info step ─────────────────────────────────────────────────────
class _WeightLossInfoStep extends StatelessWidget {
  final bool isRu;

  const _WeightLossInfoStep({required this.isRu});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: OBColors.gradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                Text(
                  isRu ? 'Отличный выбор!' : 'Great choice!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _BulletRow(
            emoji: '✅',
            text: isRu ? 'Оптимальный дефицит калорий' : 'Optimal calorie deficit',
          ),
          const SizedBox(height: 12),
          _BulletRow(
            emoji: '✅',
            text: isRu ? 'Сохраним мышечную массу' : 'Preserve muscle mass',
          ),
          const SizedBox(height: 12),
          _BulletRow(
            emoji: '✅',
            text: isRu ? 'Без чувства голода' : 'No hunger feelings',
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _BulletRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OBColors.pink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_rounded, color: OBColors.pink, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info feature data ─────────────────────────────────────────────────────────
class _InfoFeature {
  final IconData icon;
  final String textRu;
  final String textEn;
  const _InfoFeature({required this.icon, required this.textRu, required this.textEn});
}

// ─── Info step (reusable) ──────────────────────────────────────────────────────
class _InfoStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titleRu;
  final String titleEn;
  final String subtitleRu;
  final String subtitleEn;
  final List<_InfoFeature> features;
  final bool isRu;

  const _InfoStep({
    required this.icon,
    required this.iconColor,
    required this.titleRu,
    required this.titleEn,
    required this.subtitleRu,
    required this.subtitleEn,
    required this.features,
    required this.isRu,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [iconColor.withValues(alpha: 0.12), iconColor.withValues(alpha: 0.04)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: iconColor.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  isRu ? titleRu : titleEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isRu ? subtitleRu : subtitleEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FeatureRow(feature: f, color: iconColor, isRu: isRu),
          )),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _InfoFeature feature;
  final Color color;
  final bool isRu;

  const _FeatureRow({required this.feature, required this.color, required this.isRu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isRu ? feature.textRu : feature.textEn,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step: Method demo ─────────────────────────────────────────────────────────
enum _DemoMode { none, text, voice, photo }

class _MethodStep extends ConsumerStatefulWidget {
  final AppLocalizations l10n;
  const _MethodStep({required this.l10n});

  @override
  ConsumerState<_MethodStep> createState() => _MethodStepState();
}

enum _DemoLoadingType { none, voice, photo, text }

class _MethodStepState extends ConsumerState<_MethodStep> with SingleTickerProviderStateMixin {
  _DemoMode _active = _DemoMode.none;
  _DemoLoadingType _loadingType = _DemoLoadingType.none;
  bool get _loading => _loadingType != _DemoLoadingType.none;

  // Text demo
  final _textCtrl = TextEditingController();

  // Voice demo
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordPath;

  // Results
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  String get _lang => Localizations.localeOf(context).languageCode == 'ru' ? 'ru' : 'en';

  /// Returns true if the user hasn't consented yet and we navigated to the
  /// consent screen. The caller should abort their action in that case.
  bool _requireConsent() {
    final consent = ref.read(aiConsentProvider);
    if (consent != null) return false; // already decided — proceed
    ref.read(consentFromOnboardingProvider.notifier).state = true;
    context.go('/ai-consent');
    return true;
  }

  Future<void> _parseText(String text) async {
    if (_requireConsent()) return;
    if (text.trim().isEmpty) return;
    setState(() { _loadingType = _DemoLoadingType.text; _error = null; _items = []; });
    try {
      final resp = await apiDio.post('/api/onboarding/parse_meal', data: {
        'text': text,
        'language': _lang,
      });
      final list = (resp.data['items'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loadingType = _DemoLoadingType.none);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_requireConsent()) return;
    setState(() { _active = _DemoMode.photo; _items = []; _error = null; });
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) { setState(() => _active = _DemoMode.none); return; }
    setState(() => _loadingType = _DemoLoadingType.photo);
    try {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: 'photo.jpg'),
      });
      final resp = await apiDio.post('/api/onboarding/recognize_photo?language=$_lang', data: form);
      final error = resp.data['error'] as String?;
      final rawItems = resp.data['items'] as List<dynamic>?;
      if (error != null && error.isNotEmpty) {
        setState(() => _error = error);
      } else if (rawItems != null && rawItems.isNotEmpty) {
        setState(() => _items = rawItems.map((e) => e as Map<String, dynamic>).toList());
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loadingType = _DemoLoadingType.none);
    }
  }

  Future<void> _startVoice() async {
    if (_requireConsent()) return;
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _error = widget.l10n.ob_method_mic_denied);
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.l10n.ob_method_mic_denied),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          action: SnackBarAction(
            label: widget.l10n.addMeal_open_settings,
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/ob_voice.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordPath!,
    );
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopVoice() async {
    await _recorder.stop();
    setState(() { _isRecording = false; _loadingType = _DemoLoadingType.voice; _items = []; _error = null; });
    try {
      final form = FormData.fromMap({
        'audio': await MultipartFile.fromFile(_recordPath!, filename: 'voice.m4a'),
      });
      final resp = await apiDio.post('/api/onboarding/transcribe', data: form);
      final text = resp.data['text'] as String? ?? '';
      if (text.isNotEmpty) {
        _textCtrl.text = text;
        await _parseText(text);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loadingType = _DemoLoadingType.none);
    }
  }

  void _reset() {
    setState(() {
      _active = _DemoMode.none;
      _items = [];
      _error = null;
      _textCtrl.clear();
    });
  }

  Future<void> _showPhotoSourcePicker() async {
    final l10n = widget.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.addMeal_photo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _OBSourceOption(
              icon: Icons.camera_alt_rounded,
              label: l10n.addMeal_takePhoto,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
            _OBSourceOption(
              icon: Icons.photo_library_rounded,
              label: l10n.addMeal_choosePhoto,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.common_cancel,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    _pickPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.ob_method_title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(l10n.ob_method_sub,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4)),
              const SizedBox(height: 20),

              // Method tiles
              _MethodTile(
                icon: Icons.photo_camera_rounded,
                title: l10n.ob_method_photo_title,
                desc: l10n.ob_method_photo_desc,
                active: _active == _DemoMode.photo,
                onTap: _loading ? null : () {
                  AnalyticsService.onboardingMethodSelected('photo');
                  setState(() { _active = _DemoMode.photo; _items = []; _error = null; });
                  _showPhotoSourcePicker();
                },
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.mic_rounded,
                title: l10n.ob_method_voice_title,
                desc: _active == _DemoMode.voice && _isRecording
                    ? l10n.ob_method_recording
                    : l10n.ob_method_voice_desc,
                active: _active == _DemoMode.voice,
                recording: _isRecording,
                onTap: _loading ? null : () {
                  if (_active != _DemoMode.voice) {
                    AnalyticsService.onboardingMethodSelected('voice');
                    setState(() { _active = _DemoMode.voice; _items = []; _error = null; });
                    _startVoice();
                  } else if (_isRecording) {
                    _stopVoice();
                  } else {
                    _startVoice();
                  }
                },
              ),
              const SizedBox(height: 10),
              _MethodTile(
                icon: Icons.keyboard_rounded,
                title: l10n.ob_method_text_title,
                desc: l10n.ob_method_text_desc,
                active: _active == _DemoMode.text,
                onTap: _loading ? null : () {
                  AnalyticsService.onboardingMethodSelected('text');
                  setState(() {
                    _active = _DemoMode.text;
                    _items = [];
                    _error = null;
                  });
                },
              ),

              // Text input area
              if (_active == _DemoMode.text) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: l10n.ob_method_text_hint,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: OBColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: OBColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: OBColors.pink, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _loadingType == _DemoLoadingType.text ? null : () => _parseText(_textCtrl.text),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: OBColors.gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _loadingType == _DemoLoadingType.text
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(l10n.ob_method_recognize,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentOverSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.accentOver, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.accentOver))),
                      GestureDetector(onTap: _reset, child: const Icon(Icons.close, size: 16, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],

              // Results
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OBColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: OBColors.pink, size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.ob_method_recognized,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _reset,
                            child: Text(l10n.ob_method_reset,
                                style: const TextStyle(color: OBColors.pink, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._items.map((item) {
                        final sug = item['suggestions'] as List<dynamic>?;
                        final first = (sug != null && sug.isNotEmpty)
                            ? sug[0] as Map<String, dynamic>
                            : item;
                        final name = first['name'] as String? ?? item['name'] as String? ?? '';
                        final cal = (first['calories'] as num?)?.toStringAsFixed(0) ?? '?';
                        final protein = (first['protein'] as num?)?.toStringAsFixed(0);
                        final fat = (first['fat'] as num?)?.toStringAsFixed(0);
                        final carbs = (first['carbs'] as num?)?.toStringAsFixed(0);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: OBColors.pink, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                              Text(l10n.ob_method_kcal(cal),
                                  style: const TextStyle(fontSize: 13, color: OBColors.pink, fontWeight: FontWeight.w700)),
                              if (protein != null) ...[
                                const SizedBox(width: 6),
                                Text(l10n.ob_method_macros(protein, fat ?? '0', carbs ?? '0'),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OBColors.pinkSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration_rounded, color: OBColors.pink, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.ob_method_ai_success,
                          style: const TextStyle(color: OBColors.pink, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),

        // Animated recognition overlay for voice/photo
        if (_loadingType == _DemoLoadingType.voice || _loadingType == _DemoLoadingType.photo)
          _OBRecognizingOverlay(
            type: _loadingType,
            l10n: widget.l10n,
          ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool active;
  final bool recording;
  final VoidCallback? onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
    this.active = false,
    this.recording = false,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? OBColors.pinkSoft : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? OBColors.pink : OBColors.border,
            width: active ? 2 : 1,
          ),
          boxShadow: active ? OBColors.buttonShadow : AppShadow.sm,
        ),
        child: Row(
          children: [
            recording
                ? _PulsingDot()
                : Icon(icon, size: 28, color: active ? OBColors.pink : AppColors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: active ? OBColors.pink : AppColors.text,
                      )),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            Icon(
              active ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              color: active ? OBColors.pink : AppColors.textMuted,
              size: active ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.accentOver.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─── Step: Result ──────────────────────────────────────────────────────────────
class _ResultStep extends StatelessWidget {
  final AppLocalizations l10n;
  final CalculationResult preview;
  final double? currentWeight;

  const _ResultStep({
    required this.l10n,
    required this.preview,
    this.currentWeight,
  });

  @override
  Widget build(BuildContext context) {
    return PlanResultView(
      calc: preview,
      l10n: l10n,
      currentWeight: currentWeight,
    );
  }
}

// ─── Shared scaffold ───────────────────────────────────────────────────────────
class _StepScaffold extends StatelessWidget {
  final String title;
  final String hint;
  final Widget child;

  const _StepScaffold({required this.title, required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OBColors.pinkSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: OBColors.pink, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(hint,
                      style: const TextStyle(color: OBColors.pink, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

// ─── Footer CTA data ───────────────────────────────────────────────────────────
/// Carries the CTA widgets from [_buildFooter] into [OnboardingScaffold].
class _FooterCtaData {
  const _FooterCtaData({required this.primaryCta, this.secondaryCta});
  final Widget primaryCta;
  final Widget? secondaryCta;
}

// ─── Gradient button ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GradientButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: disabled ? null : OBColors.gradient,
          color: disabled ? AppColors.border : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: disabled ? [] : OBColors.buttonShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: disabled ? AppColors.textMuted : Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─── Option button ─────────────────────────────────────────────────────────────
class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OBColors.pinkSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? OBColors.pink : OBColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [] : AppShadow.sm,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? OBColors.pink : AppColors.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── Onboarding recognition overlay ───────────────────────────────────────────

class _OBRecognizingOverlay extends StatefulWidget {
  final _DemoLoadingType type;
  final AppLocalizations l10n;
  const _OBRecognizingOverlay({required this.type, required this.l10n});

  @override
  State<_OBRecognizingOverlay> createState() => _OBRecognizingOverlayState();
}

class _OBRecognizingOverlayState extends State<_OBRecognizingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVoice = widget.type == _DemoLoadingType.voice;
    final label = isVoice
        ? widget.l10n.ob_recognizing_voice
        : widget.l10n.ob_recognizing_photo;

    return Container(
      color: OBColors.bg.withValues(alpha: 0.97),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVoice)
            _OBWaveAnimation(controller: _ctrl)
          else
            _OBScanAnimation(controller: _ctrl),
          const SizedBox(height: 28),
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          _OBDotLoading(controller: _ctrl),
        ],
      ),
    );
  }
}

class _OBWaveAnimation extends StatelessWidget {
  final AnimationController controller;
  const _OBWaveAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    const barCount = 7;
    const barWidth = 7.0;
    const maxH = 50.0;
    const minH = 8.0;
    const gap = 6.0;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(color: OBColors.pinkSoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final phase = (i / barCount) * 6.2832;
              final v = t * 6.2832 + phase;
              final sine = 0.5 + 0.5 * _approxSin(v);
              final h = minH + (maxH - minH) * sine;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gap / 2),
                child: Container(
                  width: barWidth,
                  height: h,
                  decoration: BoxDecoration(
                    color: OBColors.pink,
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  double _approxSin(double x) {
    final v = (x / 6.2832) - (x / 6.2832).floorToDouble();
    return v < 0.5 ? 4 * v * (1 - 2 * v) : -1 + 4 * v * (1 - v);
  }
}

class _OBScanAnimation extends StatelessWidget {
  final AnimationController controller;
  const _OBScanAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse = 0.4 + 0.3 * (0.5 + 0.5 * _approxCos(controller.value * 6.2832));
        return SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: pulse,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(color: OBColors.pinkSoft, shape: BoxShape.circle),
                ),
              ),
              Transform.rotate(
                angle: controller.value * 6.2832,
                child: CustomPaint(size: const Size(88, 88), painter: _OBArcPainter()),
              ),
              const Icon(Icons.camera_alt_rounded, color: OBColors.pink, size: 32),
            ],
          ),
        );
      },
    );
  }

  double _approxCos(double x) {
    final v = (x / 6.2832) - (x / 6.2832).floorToDouble();
    return 1 - 8 * v * (1 - v);
  }
}

class _OBArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OBColors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), 0, 1.8, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _OBDotLoading extends StatelessWidget {
  final AnimationController controller;
  const _OBDotLoading({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final count = ((controller.value * 3).floor() % 4);
        return Text(
          '●' * count + '○' * (3 - count),
          style: const TextStyle(fontSize: 12, color: OBColors.pink, letterSpacing: 4),
        );
      },
    );
  }
}

// ─── Source option (photo picker) ──────────────────────────────────────────────
class _OBSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OBSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: OBColors.pinkSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: OBColors.pink, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step: Weight loss speed ───────────────────────────────────────────────────
class _WeightLossSpeedStep extends StatefulWidget {
  final double speedKgPerWeek;
  final ValueChanged<double> onChanged;
  final double currentWeight;
  final double targetWeight;
  final bool isRu;

  const _WeightLossSpeedStep({
    required this.speedKgPerWeek,
    required this.onChanged,
    required this.currentWeight,
    required this.targetWeight,
    required this.isRu,
  });

  @override
  State<_WeightLossSpeedStep> createState() => _WeightLossSpeedStepState();
}

class _WeightLossSpeedStepState extends State<_WeightLossSpeedStep> {
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.speedKgPerWeek;
  }

  String _goalDateLabel(double speedKgPerWeek, bool isRu) {
    final weightToLose = (widget.currentWeight - widget.targetWeight).clamp(0.0, 999.0);
    if (weightToLose <= 0) return isRu ? 'цель достигнута' : 'goal reached';
    final daysToGoal = (weightToLose * 7700 / (speedKgPerWeek * 7700 / 7)).ceil();
    final goalDate = DateTime.now().add(Duration(days: daysToGoal));
    final months = isRu
        ? ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек']
        : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${goalDate.day} ${months[goalDate.month - 1]}';
  }

  bool get _isRecommended => _speed >= 0.4 && _speed <= 0.6;

  @override
  Widget build(BuildContext context) {
    final isRu = widget.isRu;
    final title = isRu
        ? 'Как быстро вы хотите\nдостигнуть своей цели?'
        : 'How fast do you want\nto reach your goal?';
    final speedLabel = isRu ? 'Скорость похудения в неделю' : 'Weight loss speed per week';
    final recommendedLabel = isRu ? 'Рекомендуется' : 'Recommended';
    final goalLabel = isRu ? 'Вы достигнете своей цели\nк ' : 'You will reach your goal\nby ';
    final kgUnit = isRu ? ' кг' : ' kg';

    final sliderMin = 0.1;
    final sliderMax = 1.0;
    // Snap to 0.1 steps
    final sliderDivisions = 9;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 32),

          // Speed value display
          Text(
            speedLabel,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '${_speed.toStringAsFixed(1)}$kgUnit',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _isRecommended ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                recommendedLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Animal markers row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('🐢', style: TextStyle(fontSize: 28)),
                Text('🐈', style: TextStyle(fontSize: 28)),
                Text('🐇', style: TextStyle(fontSize: 28)),
              ],
            ),
          ),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: OBColors.pink,
              inactiveTrackColor: OBColors.border,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 4,
            ),
            child: Slider(
              value: _speed,
              min: sliderMin,
              max: sliderMax,
              divisions: sliderDivisions,
              onChanged: (v) {
                final snapped = (v * 10).round() / 10;
                setState(() => _speed = snapped);
                widget.onChanged(snapped);
              },
            ),
          ),

          // Scale labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.1$kgUnit', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text('0.5$kgUnit', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text('1$kgUnit', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Goal date card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OBColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$goalLabel${_goalDateLabel(_speed, isRu)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step: Reviews ─────────────────────────────────────────────────────────────
class _ReviewsStep extends StatelessWidget {
  final bool isRu;
  const _ReviewsStep({required this.isRu});

  @override
  Widget build(BuildContext context) {
    final title = isRu ? 'Покажите свою любовь' : 'Show your love';
    final subtitle = isRu
        ? 'Это приложение создано для таких, как вы'
        : 'This app was made for people like you';
    final countLabel = isRu ? '+ 2 000 000 человек' : '+ 2,000,000 people';

    final reviews = isRu ? _reviewsRu : _reviewsEn;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (_) => const Icon(
              Icons.star_rounded,
              color: Color(0xFFFBBF24),
              size: 36,
            )),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // User count with avatar circles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 28,
                child: Stack(
                  children: [
                    _AvatarCircle(color: const Color(0xFF60A5FA), offset: 0, initial: 'A'),
                    _AvatarCircle(color: const Color(0xFF34D399), offset: 18, initial: 'M'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Review cards
          ...reviews.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReviewCard(review: r),
          )),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final Color color;
  final double offset;
  final String initial;
  const _AvatarCircle({required this.color, required this.offset, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Review {
  final String name;
  final String text;
  const _Review({required this.name, required this.text});
}

const _reviewsRu = [
  _Review(
    name: 'Антон К.',
    text: 'Разобрался за минуту. Всё просто, быстро, и наконец-то вижу прогресс.',
  ),
  _Review(
    name: 'София Л.',
    text: 'Столько трекеров пробовала — всё бросала. А этот другой — пользуюсь каждый день.',
  ),
  _Review(
    name: 'Данил Б.',
    text: 'Сначала был скептичен, но приложение реально работает. За месяц минус 4 кг!',
  ),
];

const _reviewsEn = [
  _Review(
    name: 'Anton K.',
    text: 'Figured it out in a minute. Simple, fast, and I finally see real progress.',
  ),
  _Review(
    name: 'Sofia L.',
    text: 'Tried so many trackers — always quit. This one is different — use it every day.',
  ),
  _Review(
    name: 'Daniel B.',
    text: 'Was skeptical at first, but the app actually works. Minus 4 kg in one month!',
  ),
];

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OBColors.pinkSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  review.name[0],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: OBColors.pink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (_) => const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                      size: 14,
                    )),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

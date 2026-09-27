import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/ai_consent/ai_consent_provider.dart';
import 'core/analytics/analytics_service.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_handoff_coordinator.dart';
import 'core/feedback/feedback_coordinator.dart';
import 'core/feedback/feedback_repository.dart';
import 'core/feedback/feedback_metadata.dart';
import 'core/meal_logging/meal_log_incident_reporter.dart';
import 'core/notifications/notification_service.dart';
import 'features/chat/screens/chat_v2_screen.dart';
import 'router.dart';
import 'shared/models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (const bool.fromEnvironment('QA_PENDING_MEAL_PREVIEW')) {
    runApp(const PendingMealCardSimulatorPreview());
    return;
  }
  await Future.wait([
    initializeDateFormatting('ru'),
    initializeDateFormatting('en'),
  ]);

  // ── 1. Firebase first (Analytics + FCM both depend on it) ─────────────────
  await Firebase.initializeApp();

  // ── 2. Parallel: Dio setup + prefs + Analytics + FCM setup ───────────────
  final results = await Future.wait([
    initApiClient(), // pure Dio — no network calls
    SharedPreferences.getInstance(), // local disk
    AnalyticsService.init(), // Firebase already up
    NotificationService.initAfterFirebase(), // Firebase already up
    FeedbackMetadata.initialize(),
  ]);

  final prefs = results[1] as SharedPreferences;
  await FeedbackRuntime.initialize(
    preferences: prefs,
    repository: FeedbackRepository(apiDio),
  );
  await MealLogIncidentRuntime.initialize(prefs, apiDio);
  await FeedbackRuntime.coordinator?.flushAnonymous();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // Read the cached consent synchronously so the router never sees null
  // on first frame for users who have already answered — prevents the race
  // where the router briefly redirects to /ai-consent for returning users.
  final localConsent = prefs.getBool(kAiConsentLocalKey);

  // ── 3. Load cached user profile → skip loading screen for returning users ─
  UserProfile? cachedUser;
  final cachedJson = prefs.getString('cached_user');
  if (cachedJson != null) {
    try {
      cachedUser = UserProfile.fromJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
      );
    } catch (_) {
      // cache corrupted — ignore, checkSession will re-authenticate
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        onboardingDoneProvider.overrideWith((ref) => onboardingDone),
        // Pre-seed aiConsentProvider with the locally cached value so the
        // router's first evaluation never briefly redirects to /ai-consent
        // for users who already answered. Null = first launch (no key yet).
        if (localConsent != null)
          aiConsentProvider.overrideWith(() => AiConsentNotifier(localConsent)),
        // Mark consent as ready when we have a local value — the router guard
        // can then apply immediately without waiting for the async initializer.
        if (localConsent != null)
          aiConsentReadyProvider.overrideWith((ref) => true),
      ],
      child: _AppInit(cachedUser: cachedUser),
    ),
  );
}

class _AppInit extends ConsumerStatefulWidget {
  const _AppInit({this.cachedUser});
  final UserProfile? cachedUser;

  @override
  ConsumerState<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends ConsumerState<_AppInit>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(authNotifierProvider.notifier);
      final coordinator = ref.read(authHandoffCoordinatorProvider.notifier);
      unawaited(
        coordinator.resumePending().then((resumed) {
          if (resumed) return;
          if (widget.cachedUser != null) {
            notifier.restoreFromCache(widget.cachedUser!);
          }
          notifier.checkSession(backgroundRefresh: widget.cachedUser != null);
        }),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(MealLogIncidentRuntime.reporter?.flush());
      FeedbackRuntime.coordinator?.flushAnonymous();
      // backgroundRefresh: true — user sees the existing UI, no loading flash.
      final handoff = ref.read(authHandoffCoordinatorProvider);
      if (!handoff.authCompleting) {
        ref
            .read(authNotifierProvider.notifier)
            .checkSession(backgroundRefresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => const KayfitApp();
}

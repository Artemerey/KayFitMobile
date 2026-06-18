import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/analytics/analytics_service.dart';
import 'core/auth/auth_provider.dart';
import 'core/ai_consent/ai_consent_provider.dart';
import 'core/navigation/navigation_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/journal/screens/journal_screen.dart';
import 'features/journal/screens/edit_meal_screen.dart';
import 'shared/models/meal.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/settings_v2_screen.dart';
import 'features/settings/screens/goals_screen.dart';
import 'features/auth/screens/email_auth_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/way_to_goal/screens/way_to_goal_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/ai_consent/screens/ai_consent_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'features/add_meal/screens/kf2_capture_screen.dart';
import 'features/add_meal/screens/kf2_recognizing_screen.dart';
import 'features/add_meal/screens/recognition_result_args.dart';
import 'features/add_meal/screens/recognition_result_sheet_kf2.dart';
import 'shared/theme/kayfit2_theme.dart';
import 'features/chat/screens/chat_v2_screen.dart';
import 'features/journal/screens/journal_v2_screen.dart';
import 'features/recipes/screens/recipes_screen.dart';
import 'features/recipes/screens/recipe_detail_screen.dart';
import 'features/kayfit2/screens/kayfit2_preview_screen.dart';
import 'shared/widgets/bottom_nav.dart';

export 'core/navigation/navigation_providers.dart';

// Feature flag: enable the KF2 Journal redesign screen.
// Default is `true` so Xcode "Run" (which doesn't pass dart-defines) picks it up.
// To disable: --dart-define=KF2_JOURNAL=false
const _kfJournal = bool.fromEnvironment('KF2_JOURNAL', defaultValue: true);

// Feature flag: enable the KF2 Chat redesign screen.
// When active the legacy /chat route transparently redirects to /chat-v2.
const _kfChat = bool.fromEnvironment('KF2_CHAT', defaultValue: true);

// Feature flag: enable the KF2 capture + recognizing screens.
// When active, the Photo method in AddMealSheet navigates to /kf2/capture
// instead of invoking ImagePicker inline.
// ignore: unused_element
const _kfRecog = bool.fromEnvironment('KF2_RECOG', defaultValue: true);

const _kOnboardingDoneKey = 'onboarding_done';

/// Call after successful onboarding completion to mark it done.
Future<void> markOnboardingDone(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
  ref.read(onboardingDoneProvider.notifier).state = true;
}

// ---------------------------------------------------------------------------
// RouterNotifier — drives GoRouter.refreshListenable instead of rebuilding
// the entire GoRouter object on every auth/consent state change.
// ---------------------------------------------------------------------------

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // Watch auth, onboarding, consent, wayToGoal — notify GoRouter on change.
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
    _ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
    _ref.listen(showWayToGoalProvider, (_, __) => notifyListeners());
    _ref.listen(aiConsentProvider, (_, __) => notifyListeners());
    _ref.listen(aiConsentReadyProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authNotifier = _ref.read(authNotifierProvider);
    final onboardingDone = _ref.read(onboardingDoneProvider);
    final showWayToGoal = _ref.read(showWayToGoalProvider);
    final aiConsent = _ref.read(aiConsentProvider);
    final consentReady = _ref.read(aiConsentReadyProvider);

    final loc = state.matchedLocation;

    // While the auth state is resolving, park on the branded splash so we never
    // flash the legacy initialLocation '/' (DashboardScreen) or a half-resolved
    // screen on the first frame. checkSession's loading() safety net guarantees
    // isLoading eventually flips, so this can never be permanent.
    if (authNotifier.isLoading) {
      return loc == '/splash' ? null : '/splash';
    }

    final isLoggedIn = authNotifier.value != null;

    // Auth resolved — leave the splash for the real destination. Sending a
    // logged-in user to /journal-v2 lets the gates below (way-to-goal,
    // ai-consent, review-prompt) re-fire on the next redirect as usual.
    if (loc == '/splash') {
      if (!isLoggedIn) return onboardingDone ? '/login' : '/onboarding';
      return _kfJournal ? '/journal-v2' : '/';
    }

    // Public routes
    final isPublic = loc == '/login' ||
        loc == '/email-auth' ||
        loc == '/onboarding' ||
        loc == '/way-to-goal' ||
        loc == '/ai-consent' ||
        loc == '/kayfit2/preview';

    if (!isLoggedIn) {
      if (isPublic) return null;
      return onboardingDone ? '/login' : '/onboarding';
    }

    // Logged in
    if (loc == '/login' || loc == '/email-auth') {
      return _kfJournal ? '/journal-v2' : '/';
    }
    // After completing onboarding, leave /onboarding
    if (loc == '/onboarding' && onboardingDone) {
      return _kfJournal ? '/journal-v2' : '/';
    }
    // Reinstall case: Keychain auth token survives reinstall but SharedPreferences
    // are cleared — user is logged in but onboarding not done. Show onboarding.
    if (!onboardingDone && loc != '/onboarding') {
      return '/onboarding';
    }

    if (showWayToGoal && loc != '/way-to-goal') {
      return '/way-to-goal';
    }

    // KF2 Journal flag: redirect home to the V2 redesign.
    if (_kfJournal && loc == '/') {
      return '/journal-v2';
    }

    // KF2 Chat flag: transparently switch the legacy /chat tab to /chat-v2.
    // Navigation from JournalV2Screen still calls context.go('/chat'); this
    // redirect intercepts that and sends the user to the new screen instead.
    if (_kfChat && loc == '/chat') {
      return '/chat-v2';
    }

    // KF2 Journal flag: settings must not inherit the legacy ShellRoute bottom
    // nav when the user arrives from JournalV2Screen.  Redirect /settings to
    // /settings-v2, which is a plain GoRoute outside the ShellRoute — it
    // renders SettingsScreen with an auto-implied back button and no bottom nav.
    if (_kfJournal && loc == '/settings') {
      return '/settings-v2';
    }

    // AI consent screen is shown only when the user has never answered (null).
    // Declined users (false) pass through — AI features are disabled individually
    // in each screen (chat, dashboard, recognition). Forcing sign-out on decline
    // violates App Store Guideline 5.1.1 (consent must be freely given).
    // consentReady guard: on reinstall SharedPreferences is cleared but the
    // Keychain auth token survives, so aiConsent starts null and the notifier
    // must first verify with the server.  We hold off the redirect until the
    // async check completes to avoid showing the screen to returning users.
    if (consentReady && isLoggedIn && aiConsent == null && !showWayToGoal &&
        loc != '/ai-consent' && loc != '/way-to-goal' &&
        loc != '/kayfit2/preview') {
      return '/ai-consent';
    }

    return null;
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

/// Debug-only escape hatch for VM Service-driven test automation.
/// Captures the live [GoRouter] instance so external tooling can invoke
/// `debugRouter!.push(...)` via Dart eval without needing a BuildContext.
/// NEVER reference this from production code paths.
GoRouter? debugRouter;

/// Observer used by screens that need to know when they regain focus after a
/// pushed route pops (e.g. the chat screen flushing queued recognition results
/// once the camera/result route closes). A single shared instance so RouteAware
/// subscribers receive callbacks.
final RouteObserver<PageRoute<dynamic>> kf2RouteObserver =
    RouteObserver<PageRoute<dynamic>>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  final router = GoRouter(
    initialLocation: '/splash',
    observers: [AnalyticsService.routeObserver, kf2RouteObserver],
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/email-auth',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: '/way-to-goal',
        builder: (context, state) => const WayToGoalScreen(),
      ),
      GoRoute(
        path: '/ai-consent',
        builder: (context, state) => const AiConsentScreen(),
      ),
      GoRoute(
        path: '/settings/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/kayfit2/preview',
        builder: (context, state) => const Kayfit2PreviewScreen(),
      ),
      GoRoute(
        path: '/journal-v2',
        builder: (context, state) => const JournalV2Screen(),
      ),
      GoRoute(
        path: '/chat-v2',
        builder: (context, state) => const ChatV2Screen(),
      ),
      // Recipes (phase 5): RAG recommendation list + carousel viewer.
      // Standalone KF2 routes outside the ShellRoute — each owns its own
      // top bar with a back button (like /journal-v2, /settings-v2).
      GoRoute(
        path: '/recipes',
        builder: (context, state) => const RecipesScreen(),
      ),
      GoRoute(
        path: '/recipes/:slug',
        builder: (context, state) =>
            RecipeDetailScreen(slug: state.pathParameters['slug']!),
      ),
      // KF2 Journal: settings without the legacy ShellRoute bottom nav.
      // SettingsV2Screen owns its own KF2-style top bar with an explicit back
      // button — no dependency on the shell or automaticallyImplyLeading.
      GoRoute(
        path: '/settings-v2',
        builder: (context, state) => const SettingsV2Screen(),
      ),
      GoRoute(
        path: '/meals/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          // When the caller has the Meal in hand (Journal list, dashboard) it
          // passes it via `extra`, so we can render instantly without the
          // /api/meals/history round-trip. Falls back to network when null.
          final initial = state.extra is Meal ? state.extra as Meal : null;
          return EditMealScreen(mealId: id, initial: initial);
        },
      ),

      // ── KF2-RECOG: capture + recognizing full-screen flow ──────────────
      // Opened programmatically from AddMealSheet when _kfRecog is true.
      // Not protected by a redirect — AddMealSheet already handles auth context.
      GoRoute(
        path: '/kf2/capture',
        builder: (context, state) => const Kf2CaptureScreen(),
      ),
      GoRoute(
        path: '/kf2/recognizing',
        builder: (context, state) {
          final photo = state.extra as XFile;
          return Kf2RecognizingScreen(photo: photo);
        },
      ),
      // Recognition result sheet, presented as a real router page so the
      // sheet's Navigator.pop stays in sync with go_router. Opened by the chat
      // screen when a background photo recognition completes.
      GoRoute(
        path: '/kf2/result',
        builder: (context, state) {
          final args = state.extra as RecognitionResultArgs;
          return Scaffold(
            backgroundColor: K2Colors.darkBg,
            body: RecognitionResultSheetKF2(
              dishName: args.dishName,
              ingredients: args.items,
              mealDate: null,
              originalText: null,
              onSaved: args.onSaved,
            ),
          );
        },
      ),

      ShellRoute(
        builder: (context, state, child) => ScaffoldWithBottomNav(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/journal',
            builder: (context, state) => const JournalScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  debugRouter = router;
  return router;
});

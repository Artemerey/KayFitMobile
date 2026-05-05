import 'package:flutter/foundation.dart';
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
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/screens/goals_screen.dart';
import 'features/auth/screens/email_auth_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/way_to_goal/screens/way_to_goal_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/ai_consent/screens/ai_consent_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'features/add_meal/screens/kf2_capture_screen.dart';
import 'features/add_meal/screens/kf2_recognizing_screen.dart';
import 'features/chat/screens/chat_v2_screen.dart';
import 'features/journal/screens/journal_v2_screen.dart';
import 'features/kayfit2/screens/kayfit2_preview_screen.dart';
import 'shared/widgets/bottom_nav.dart';

export 'core/navigation/navigation_providers.dart';

// Feature flag: enable the KF2 Journal redesign screen.
// Activate with: flutter run --dart-define=KF2_JOURNAL=true
const _kfJournal = bool.fromEnvironment('KF2_JOURNAL', defaultValue: false);

// Feature flag: enable the KF2 Chat redesign screen.
// Activate with: flutter run --dart-define=KF2_CHAT=true
// When active the legacy /chat route transparently redirects to /chat-v2.
const _kfChat = bool.fromEnvironment('KF2_CHAT', defaultValue: false);

// Feature flag: enable the KF2 capture + recognizing screens.
// Activate with: flutter run --dart-define=KF2_RECOG=true
// When active, the Photo method in AddMealSheet navigates to /kf2/capture
// instead of invoking ImagePicker inline.
// ignore: unused_element
const _kfRecog = bool.fromEnvironment('KF2_RECOG', defaultValue: false);

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
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authNotifier = _ref.read(authNotifierProvider);
    final onboardingDone = _ref.read(onboardingDoneProvider);
    final showWayToGoal = _ref.read(showWayToGoalProvider);
    final aiConsent = _ref.read(aiConsentProvider);

    if (authNotifier.isLoading) return null;

    final isLoggedIn = authNotifier.value != null;
    final loc = state.matchedLocation;

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
    if (loc == '/login' || loc == '/email-auth' || loc == '/onboarding') {
      return _kfJournal ? '/journal-v2' : '/';
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

    // AI consent is MANDATORY: only `true` lets the user past this gate.
    // `null` (never answered) and `false` (declined) both redirect back.
    // /kayfit2/preview is exempt — it's a design preview screen.
    if (isLoggedIn && aiConsent != true && !showWayToGoal &&
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

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    observers: [AnalyticsService.routeObserver],
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
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
      // KF2 Journal: settings without the legacy ShellRoute bottom nav.
      // Identical screen to /settings — the ShellRoute wrapper is simply absent.
      // The SliverAppBar inside SettingsScreen has automaticallyImplyLeading=true
      // (Flutter default), so the OS back button is shown automatically.
      GoRoute(
        path: '/settings-v2',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/meals/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EditMealScreen(mealId: id);
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
});

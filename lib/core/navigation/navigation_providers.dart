import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the onboarding flow has been completed this session.
/// Loaded once at startup from SharedPreferences.
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

/// Set to true after email auth when onboarding data was synced.
/// Router redirects to /way-to-goal once; WayToGoalScreen clears it.
final showWayToGoalProvider = StateProvider<bool>((ref) => false);

/// Set to true when AI consent is triggered from onboarding demo.
/// AiConsentScreen uses this to navigate back to /onboarding after consent.
final consentFromOnboardingProvider = StateProvider<bool>((ref) => false);

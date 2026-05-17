import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_provider.dart';
import 'core/notifications/notification_service.dart';
import 'router.dart';
import 'shared/models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase first (Analytics + FCM both depend on it) ─────────────────
  await Firebase.initializeApp();

  // ── 2. Parallel: Dio setup + prefs + Analytics + FCM setup ───────────────
  final results = await Future.wait([
    initApiClient(),                    // pure Dio — no network calls
    SharedPreferences.getInstance(),    // local disk
    AnalyticsService.init(),            // Firebase already up
    NotificationService.initAfterFirebase(), // Firebase already up
  ]);

  final prefs = results[1] as SharedPreferences;
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

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
      if (widget.cachedUser != null) {
        notifier.restoreFromCache(widget.cachedUser!);
      }
      notifier.checkSession(backgroundRefresh: widget.cachedUser != null);
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
      // backgroundRefresh: true — user sees the existing UI, no loading flash.
      ref
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) => const KayfitApp();
}

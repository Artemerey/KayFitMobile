import 'package:flutter/material.dart';

/// Neutral branded splash shown while the auth state is still resolving.
///
/// Used as GoRouter's `initialLocation` and as the parking route whenever
/// `authNotifier.isLoading` is true. Its background and logo match the native
/// launch screen (`flutter_native_splash` color `#16A34A`) so the hand-off from
/// the OS splash to the first Flutter frame is seamless — no flash of the legacy
/// `/` (DashboardScreen) before the redirect resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Brand green — kept in sync with `flutter_native_splash.color` in pubspec.
  static const Color _brand = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _brand,
      body: Center(
        child: Image(
          image: AssetImage('assets/icon/icon.png'),
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

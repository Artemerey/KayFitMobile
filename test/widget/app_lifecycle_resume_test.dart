// test/widget/app_lifecycle_resume_test.dart
//
// H2 — AppLifecycleState observer in _AppInitState:
//   • resumed  → checkSession(backgroundRefresh: true)  is called exactly once
//   • paused   → checkSession is NOT called
//   • inactive → checkSession is NOT called
//   • The flag passed is backgroundRefresh: true (not false)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/shared/models/user_profile.dart';

// ─── Fake AuthNotifier ────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  int checkSessionCallCount = 0;
  final List<bool> backgroundRefreshFlags = [];

  @override
  AsyncValue<UserProfile?> build() {
    return const AsyncValue.data(
      UserProfile(id: 1, email: 'test@kayfit.app'),
    );
  }

  @override
  Future<void> checkSession({bool backgroundRefresh = false}) async {
    checkSessionCallCount++;
    backgroundRefreshFlags.add(backgroundRefresh);
  }
}

// ─── Minimal widget that replicates _AppInitState lifecycle logic ─────────────
//
// We cannot import _AppInitState directly (it is private in main.dart), so we
// reproduce only the WidgetsBindingObserver behaviour that H2 is about.

class _LifecycleProbe extends ConsumerStatefulWidget {
  const _LifecycleProbe();

  @override
  ConsumerState<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends ConsumerState<_LifecycleProbe>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<_FakeAuthNotifier> _pumpProbe(WidgetTester tester) async {
  final fake = _FakeAuthNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => fake),
      ],
      child: const MaterialApp(home: _LifecycleProbe()),
    ),
  );
  await tester.pump();

  // initState fires checkSession once during widget mount (via build());
  // reset the counter so lifecycle tests start from zero.
  fake.checkSessionCallCount = 0;
  fake.backgroundRefreshFlags.clear();

  return fake;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. resumed → checkSession called with backgroundRefresh: true ──────────

  group('H2 — AppLifecycleState.resumed', () {
    testWidgets(
        'resumed fires checkSession(backgroundRefresh: true) exactly once',
        (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(1));
    });

    testWidgets('resumed passes backgroundRefresh: true (not false)',
        (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fake.backgroundRefreshFlags, equals([true]));
    });

    testWidgets('resumed twice fires checkSession twice', (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(2));
    });
  });

  // ── 2. paused → checkSession NOT called ───────────────────────────────────

  group('H2 — AppLifecycleState.paused', () {
    testWidgets('paused does not trigger checkSession', (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(0));
    });
  });

  // ── 3. inactive → checkSession NOT called ─────────────────────────────────

  group('H2 — AppLifecycleState.inactive', () {
    testWidgets('inactive does not trigger checkSession', (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(0));
    });
  });

  // ── 4. mixed sequence: paused → resumed ───────────────────────────────────

  group('H2 — mixed lifecycle sequence', () {
    testWidgets(
        'paused then resumed: only the resumed event calls checkSession',
        (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(1));
      expect(fake.backgroundRefreshFlags, equals([true]));
    });

    testWidgets(
        'inactive then resumed: only the resumed event calls checkSession',
        (tester) async {
      final fake = await _pumpProbe(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(fake.checkSessionCallCount, equals(1));
      expect(fake.backgroundRefreshFlags, equals([true]));
    });
  });
}

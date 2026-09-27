import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/auth/auth_handoff_coordinator.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:kayfit/core/storage/onboarding_pending_storage.dart';
import 'package:kayfit/router.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStorage implements SecureTokenStorage {
  TokenPair? pair;
  int saveCount = 0;

  @override
  Future<void> saveTokens(TokenPair value) async {
    pair = value;
    saveCount++;
  }

  @override
  Future<TokenPair?> loadTokens() async => pair;
  @override
  Future<String?> loadAccessToken() async => pair?.accessToken;
  @override
  Future<String?> loadRefreshToken() async => pair?.refreshToken;
  @override
  Future<void> clearTokens() async => pair = null;
}

TokenPair _pair() => TokenPair(
  accessToken: 'access-secret',
  refreshToken: 'refresh-secret',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

const _user = UserProfile(id: 42, email: 'private@example.com');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor({
    required _MemoryTokenStorage storage,
    required Future<void> Function() sync,
    required Future<UserProfile> Function() load,
  }) {
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        authHandoffCoordinatorProvider.overrideWith((ref) {
          return AuthHandoffCoordinator(
            ref,
            syncOnboarding: sync,
            loadUser: load,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('router remains authCompleting throughout exchange and sync', () async {
    final exchange = Completer<TokenPair>();
    final sync = Completer<void>();
    final storage = _MemoryTokenStorage();
    final container = containerFor(
      storage: storage,
      sync: () => sync.future,
      load: () async => _user,
    );
    final coordinator = container.read(authHandoffCoordinatorProvider.notifier);

    final future = coordinator.run(
      handoffId: 'same-callback',
      source: AuthHandoffSource.appleLogin,
      exchange: () => exchange.future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authHandoffCoordinatorProvider).phase,
      AuthHandoffPhase.exchanging,
    );
    expect(
      authHandoffRedirect(authCompleting: true, location: '/login'),
      '/auth-completing',
    );

    exchange.complete(_pair());
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authHandoffCoordinatorProvider).phase,
      AuthHandoffPhase.syncingOnboarding,
    );
    expect(
      authHandoffRedirect(authCompleting: true, location: '/onboarding'),
      '/auth-completing',
    );
    expect(container.read(authNotifierProvider).value, isNull);

    sync.complete();
    await future;
    expect(
      container.read(authHandoffCoordinatorProvider).phase,
      AuthHandoffPhase.authenticated,
    );
    expect(container.read(authNotifierProvider).value, _user);
  });

  test('authenticated is published only after profile load', () async {
    final profile = Completer<UserProfile>();
    final container = containerFor(
      storage: _MemoryTokenStorage(),
      sync: () async {},
      load: () => profile.future,
    );
    final phases = <AuthHandoffPhase>[];
    container.listen<AuthHandoffState>(
      authHandoffCoordinatorProvider,
      (_, next) => phases.add(next.phase),
    );
    final future = container
        .read(authHandoffCoordinatorProvider.notifier)
        .run(
          handoffId: 'profile-gate',
          source: AuthHandoffSource.emailLogin,
          exchange: () async => _pair(),
        );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authNotifierProvider).value, isNull);
    profile.complete(_user);
    await future;
    expect(
      phases,
      containsAllInOrder(<AuthHandoffPhase>[
        AuthHandoffPhase.exchanging,
        AuthHandoffPhase.syncingOnboarding,
        AuthHandoffPhase.loadingUser,
        AuthHandoffPhase.authenticated,
      ]),
    );
  });

  test('duplicate Apple callback shares one exchange and one sync', () async {
    var exchanges = 0;
    var syncs = 0;
    final gate = Completer<TokenPair>();
    final container = containerFor(
      storage: _MemoryTokenStorage(),
      sync: () async => syncs++,
      load: () async => _user,
    );
    final coordinator = container.read(authHandoffCoordinatorProvider.notifier);
    Future<TokenPair> exchange() {
      exchanges++;
      return gate.future;
    }

    final first = coordinator.run(
      handoffId: 'apple-callback-id',
      source: AuthHandoffSource.appleLogin,
      exchange: exchange,
    );
    final duplicate = coordinator.run(
      handoffId: 'apple-callback-id',
      source: AuthHandoffSource.appleLogin,
      exchange: exchange,
    );
    gate.complete(_pair());
    await Future.wait([first, duplicate]);
    expect(exchanges, 1);
    expect(syncs, 1);
  });

  test(
    'coordinator completes after the initiating screen is disposed',
    () async {
      final exchange = Completer<TokenPair>();
      final container = containerFor(
        storage: _MemoryTokenStorage(),
        sync: () async {},
        load: () async => _user,
      );
      final future = container
          .read(authHandoffCoordinatorProvider.notifier)
          .run(
            handoffId: 'disposed-screen',
            source: AuthHandoffSource.appleLogin,
            exchange: () => exchange.future,
          );
      // No BuildContext or widget ownership exists after this point.
      exchange.complete(_pair());
      await future;
      expect(container.read(authNotifierProvider).value, _user);
    },
  );

  test(
    'cold start resumes post-exchange handoff without exchanging again',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_handoff_pending_v1':
            '{"handoff_id":"cold","source":"appleLogin","phase":"syncingOnboarding"}',
      });
      final storage = _MemoryTokenStorage()..pair = _pair();
      var syncs = 0;
      final container = containerFor(
        storage: storage,
        sync: () async => syncs++,
        load: () async => _user,
      );
      expect(
        await container
            .read(authHandoffCoordinatorProvider.notifier)
            .resumePending(),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(syncs, 1);
      expect(storage.saveCount, 0);
      expect(container.read(authNotifierProvider).value, _user);
    },
  );

  test(
    'existing authenticated session is unchanged without pending handoff',
    () async {
      final container = containerFor(
        storage: _MemoryTokenStorage()..pair = _pair(),
        sync: () async => fail('sync must not run'),
        load: () async => fail('profile load must not run'),
      );
      container.read(authNotifierProvider.notifier).restoreFromCache(_user);
      expect(
        await container
            .read(authHandoffCoordinatorProvider.notifier)
            .resumePending(),
        isFalse,
      );
      expect(container.read(authNotifierProvider).value, _user);
      expect(
        container.read(authHandoffCoordinatorProvider).phase,
        AuthHandoffPhase.idle,
      );
    },
  );

  test(
    'cold start during exchange requires safe repeat and rejects stale pair',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_handoff_pending_v1':
            '{"handoff_id":"interrupted","source":"appleLogin","phase":"exchanging"}',
      });
      final container = containerFor(
        storage: _MemoryTokenStorage()..pair = _pair(),
        sync: () async => fail('stale tokens must not be adopted'),
        load: () async => fail('stale profile must not load'),
      );
      expect(
        await container
            .read(authHandoffCoordinatorProvider.notifier)
            .resumePending(),
        isTrue,
      );
      final state = container.read(authHandoffCoordinatorProvider);
      expect(state.phase, AuthHandoffPhase.failed);
      expect(state.errorCode, AuthHandoffErrorCode.exchangeInterrupted);
      expect(container.read(authNotifierProvider).value, isNull);
    },
  );

  test(
    'sync failure keeps pending onboarding and never authenticates',
    () async {
      await OnboardingPendingStorage.save(const OnboardingPendingData(age: 30));
      final container = containerFor(
        storage: _MemoryTokenStorage(),
        sync: () async => throw StateError('sync failed'),
        load: () async => _user,
      );
      await expectLater(
        container
            .read(authHandoffCoordinatorProvider.notifier)
            .run(
              handoffId: 'sync-failure',
              source: AuthHandoffSource.appleLogin,
              exchange: () async => _pair(),
            ),
        throwsA(
          isA<AuthHandoffException>().having(
            (value) => value.code,
            'code',
            AuthHandoffErrorCode.onboardingSyncFailed,
          ),
        ),
      );
      expect(await OnboardingPendingStorage.read(), isNotNull);
      expect(container.read(authNotifierProvider).value, isNull);
    },
  );

  test('profile failure never publishes authenticated', () async {
    final container = containerFor(
      storage: _MemoryTokenStorage(),
      sync: () async {},
      load: () async => throw StateError('profile failed'),
    );
    await expectLater(
      container
          .read(authHandoffCoordinatorProvider.notifier)
          .run(
            handoffId: 'profile-failure',
            source: AuthHandoffSource.appleRegistration,
            exchange: () async => _pair(),
          ),
      throwsA(isA<AuthHandoffException>()),
    );
    expect(container.read(authNotifierProvider).value, isNull);
  });

  test('login and registration sources use the same coordinator', () async {
    for (final source in <AuthHandoffSource>[
      AuthHandoffSource.appleLogin,
      AuthHandoffSource.appleRegistration,
      AuthHandoffSource.emailLogin,
      AuthHandoffSource.emailRegistration,
    ]) {
      SharedPreferences.setMockInitialValues({});
      final container = containerFor(
        storage: _MemoryTokenStorage(),
        sync: () async {},
        load: () async => _user,
      );
      await container
          .read(authHandoffCoordinatorProvider.notifier)
          .run(
            handoffId: source.name,
            source: source,
            exchange: () async => _pair(),
          );
      expect(container.read(authHandoffCoordinatorProvider).source, source);
    }
  });

  test(
    'safe incidents and logs contain no credentials or stack trace',
    () async {
      final logs = <String>[];
      final container = containerFor(
        storage: _MemoryTokenStorage(),
        sync: () async => throw StateError(
          'identity-token authorization-code private@example.com access-secret '
          'refresh-secret\n#0 raw stack',
        ),
        load: () async => _user,
      );
      await runZoned(
        () async {
          await expectLater(
            container
                .read(authHandoffCoordinatorProvider.notifier)
                .run(
                  handoffId: 'privacy',
                  source: AuthHandoffSource.appleLogin,
                  exchange: () async => _pair(),
                ),
            throwsA(isA<AuthHandoffException>()),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, message) => logs.add(message),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final evidence =
          '${prefs.getStringList('auth_handoff_incidents_v1')}$logs';
      for (final secret in <String>[
        'identity-token',
        'authorization-code',
        'private@example.com',
        'access-secret',
        'refresh-secret',
        '#0 raw stack',
      ]) {
        expect(evidence, isNot(contains(secret)));
      }
      expect(evidence, contains('onboardingSyncFailed'));
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/user_profile.dart';
import '../api/api_client.dart';
import '../navigation/navigation_providers.dart';
import 'auth_provider.dart';
import 'onboarding_sync.dart';
import 'social_auth_service.dart';

const _markerKey = 'auth_handoff_pending_v1';
const _commitKey = 'auth_handoff_commit_v1';
const _incidentKey = 'auth_handoff_incidents_v1';

enum AuthHandoffPhase {
  idle,
  exchanging,
  syncingOnboarding,
  loadingUser,
  authenticated,
  failed,
}

enum AuthHandoffSource {
  appleLogin,
  appleRegistration,
  emailLogin,
  emailRegistration,
}

enum AuthHandoffErrorCode {
  exchangeFailed,
  exchangeInterrupted,
  onboardingSyncFailed,
  profileLoadFailed,
  localCommitFailed,
}

@immutable
class AuthHandoffState {
  const AuthHandoffState({
    this.phase = AuthHandoffPhase.idle,
    this.handoffId,
    this.source,
    this.errorCode,
  });

  final AuthHandoffPhase phase;
  final String? handoffId;
  final AuthHandoffSource? source;
  final AuthHandoffErrorCode? errorCode;

  bool get authCompleting => switch (phase) {
    AuthHandoffPhase.exchanging ||
    AuthHandoffPhase.syncingOnboarding ||
    AuthHandoffPhase.loadingUser => true,
    _ => false,
  };
}

class AuthHandoffException implements Exception {
  const AuthHandoffException(this.code);
  final AuthHandoffErrorCode code;

  @override
  String toString() => 'AuthHandoffException(${code.name})';
}

typedef TokenExchange = Future<TokenPair> Function();
typedef OnboardingSync = Future<void> Function();
typedef UserLoader = Future<UserProfile> Function();

final authHandoffCoordinatorProvider =
    StateNotifierProvider<AuthHandoffCoordinator, AuthHandoffState>((ref) {
      return AuthHandoffCoordinator(ref);
    });

class AuthHandoffCoordinator extends StateNotifier<AuthHandoffState> {
  AuthHandoffCoordinator(
    this._ref, {
    SharedPreferences? preferences,
    OnboardingSync? syncOnboarding,
    UserLoader? loadUser,
  }) : _preferences = preferences,
       _syncOnboarding = syncOnboarding,
       _loadUser = loadUser,
       super(const AuthHandoffState());

  final Ref _ref;
  SharedPreferences? _preferences;
  final OnboardingSync? _syncOnboarding;
  final UserLoader? _loadUser;
  final Map<String, Future<UserProfile>> _operations = {};
  final Set<String> _completed = {};

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<UserProfile> signInWithApple({
    required AuthHandoffSource source,
    String? handoffId,
  }) {
    return run(
      handoffId: handoffId ?? _newHandoffId(),
      source: source,
      exchange: () async =>
          TokenPair.fromApiResponse(await SocialAuthService.signInWithApple()),
    );
  }

  Future<UserProfile> authenticateWithEmail({
    required AuthHandoffSource source,
    required String email,
    required String password,
    String? username,
    String? handoffId,
  }) {
    return run(
      handoffId: handoffId ?? _newHandoffId(),
      source: source,
      exchange: () async {
        final path = source == AuthHandoffSource.emailRegistration
            ? '/api/v1/auth/register'
            : '/api/v1/auth/login';
        final response = await apiDio.post<Map<String, dynamic>>(
          path,
          data: <String, dynamic>{
            'email': email,
            'password': password,
            if (username != null && username.isNotEmpty) 'username': username,
          },
        );
        return TokenPair.fromApiResponse(response.data!);
      },
    );
  }

  Future<UserProfile> run({
    required String handoffId,
    required AuthHandoffSource source,
    required TokenExchange exchange,
  }) {
    if (_completed.contains(handoffId)) {
      final user = _ref.read(authNotifierProvider).value;
      if (user != null) return Future.value(user);
    }
    return _operations.putIfAbsent(
      handoffId,
      () => _run(handoffId: handoffId, source: source, exchange: exchange),
    );
  }

  Future<UserProfile> _run({
    required String handoffId,
    required AuthHandoffSource source,
    required TokenExchange exchange,
  }) async {
    state = AuthHandoffState(
      phase: AuthHandoffPhase.exchanging,
      handoffId: handoffId,
      source: source,
    );
    await _saveMarker(handoffId, source, AuthHandoffPhase.exchanging);
    try {
      final pair = await exchange();
      await _ref.read(secureStorageProvider).saveTokens(pair);
    } on SignInCancelledException {
      await (await _prefs).remove(_markerKey);
      state = const AuthHandoffState();
      rethrow;
    } catch (_) {
      await _fail(AuthHandoffErrorCode.exchangeFailed, source);
      throw const AuthHandoffException(AuthHandoffErrorCode.exchangeFailed);
    }
    return _continueAfterExchange(handoffId, source);
  }

  Future<UserProfile> _continueAfterExchange(
    String handoffId,
    AuthHandoffSource source,
  ) async {
    state = AuthHandoffState(
      phase: AuthHandoffPhase.syncingOnboarding,
      handoffId: handoffId,
      source: source,
    );
    await _saveMarker(handoffId, source, AuthHandoffPhase.syncingOnboarding);
    try {
      if (_syncOnboarding != null) {
        await _syncOnboarding();
      } else {
        await syncOnboardingPending(throwOnFailure: true);
      }
    } catch (_) {
      await _fail(AuthHandoffErrorCode.onboardingSyncFailed, source);
      throw const AuthHandoffException(
        AuthHandoffErrorCode.onboardingSyncFailed,
      );
    }

    state = AuthHandoffState(
      phase: AuthHandoffPhase.loadingUser,
      handoffId: handoffId,
      source: source,
    );
    await _saveMarker(handoffId, source, AuthHandoffPhase.loadingUser);
    UserProfile user;
    try {
      user = _loadUser != null ? await _loadUser() : await _fetchUser();
    } catch (_) {
      await _fail(AuthHandoffErrorCode.profileLoadFailed, source);
      throw const AuthHandoffException(AuthHandoffErrorCode.profileLoadFailed);
    }

    try {
      await _commitLocalState(handoffId, user);
      await _ref.read(authNotifierProvider.notifier).publishAuthenticated(user);
      _ref.read(onboardingDoneProvider.notifier).state = true;
    } catch (_) {
      await _fail(AuthHandoffErrorCode.localCommitFailed, source);
      throw const AuthHandoffException(AuthHandoffErrorCode.localCommitFailed);
    }

    _completed.add(handoffId);
    await (await _prefs).remove(_markerKey);
    state = AuthHandoffState(
      phase: AuthHandoffPhase.authenticated,
      handoffId: handoffId,
      source: source,
    );
    return user;
  }

  Future<bool> resumePending() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_markerKey);
    if (raw == null) return false;
    final marker = jsonDecode(raw) as Map<String, dynamic>;
    final id = marker['handoff_id'] as String;
    final source = AuthHandoffSource.values.byName(marker['source'] as String);
    final phase = AuthHandoffPhase.values.byName(marker['phase'] as String);
    // There is no durable proof that a token pair belongs to an exchange that
    // crashed before the next marker. Never adopt a possibly stale session;
    // safely repeat Apple/email auth instead.
    if (phase == AuthHandoffPhase.exchanging) {
      await prefs.remove(_markerKey);
      await _fail(AuthHandoffErrorCode.exchangeInterrupted, source);
      return true;
    }
    final pair = await _ref.read(secureStorageProvider).loadTokens();
    if (pair == null) {
      await _fail(AuthHandoffErrorCode.exchangeInterrupted, source);
      return true;
    }
    _operations[id] = _continueAfterExchange(id, source);
    unawaited(_operations[id]!.then<void>((_) {}, onError: (_) {}));
    return true;
  }

  Future<UserProfile> _fetchUser() async {
    final response = await apiDio.get<Map<String, dynamic>>('/api/v1/auth/me');
    return UserProfile.fromJson(response.data!);
  }

  Future<void> _commitLocalState(String handoffId, UserProfile user) async {
    final prefs = await _prefs;
    final userJson = user.toJson();
    // Canonical single-value commit is written first. The legacy mirrors are
    // maintained for existing startup code, but never drive router decisions
    // while authCompleting is active.
    await prefs.setString(
      _commitKey,
      jsonEncode(<String, Object?>{
        'handoff_id': handoffId,
        'onboarding_done': true,
        'user': userJson,
      }),
    );
    await Future.wait([
      prefs.setString('cached_user', jsonEncode(userJson)),
      prefs.setBool('onboarding_done', true),
    ]);
  }

  Future<void> _saveMarker(
    String handoffId,
    AuthHandoffSource source,
    AuthHandoffPhase phase,
  ) async {
    await (await _prefs).setString(
      _markerKey,
      jsonEncode(<String, String>{
        'handoff_id': handoffId,
        'source': source.name,
        'phase': phase.name,
      }),
    );
  }

  Future<void> _fail(
    AuthHandoffErrorCode code,
    AuthHandoffSource source,
  ) async {
    final failedAt = state.phase;
    state = AuthHandoffState(
      phase: AuthHandoffPhase.failed,
      handoffId: state.handoffId,
      source: source,
      errorCode: code,
    );
    final prefs = await _prefs;
    final existing = prefs.getStringList(_incidentKey) ?? <String>[];
    await prefs.setStringList(_incidentKey, <String>[
      ...existing,
      jsonEncode(<String, String>{
        'error_code': code.name,
        'stage': failedAt.name,
        'source': source.name,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ]);
    debugPrint('[auth_handoff] failed code=${code.name} source=${source.name}');
  }

  static String _newHandoffId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

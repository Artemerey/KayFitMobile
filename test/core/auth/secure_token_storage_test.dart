// test/core/auth/secure_token_storage_test.dart
//
// Unit tests for SecureTokenStorageImpl.
//
// flutter_secure_storage does not offer a built-in in-memory mock.
// We define a minimal fake — FakeFlutterSecureStorage — that wraps a Map,
// then inject it via SecureTokenStorageImpl.withStorage().
//
// The migration path (SharedPreferences → SecureStorage) is tested via
// SharedPreferences.setMockInitialValues().

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fake FlutterSecureStorage ────────────────────────────────────────────────

class FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  /// Set to true to simulate a generic Keychain PlatformException on read.
  bool throwOnRead = false;

  /// Set to true to simulate errSecInteractionNotAllowed (-25308): Keychain
  /// locked after device reboot before first user unlock.
  bool throwKeychainUnavailable = false;

  // Satisfy interface members not relevant to these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  AndroidOptions get aOptions =>
      const AndroidOptions(encryptedSharedPreferences: true);

  @override
  IOSOptions get iOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  @override
  LinuxOptions get lOptions => const LinuxOptions();

  @override
  MacOsOptions get mOptions => const MacOsOptions();

  @override
  WebOptions get webOptions => const WebOptions();

  @override
  WindowsOptions get wOptions => const WindowsOptions();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwKeychainUnavailable) throw PlatformException(code: '-25308');
    if (throwOnRead) throw PlatformException(code: 'keychain_error');
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.containsKey(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.unmodifiable(_store);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.clear();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

TokenPair _makeTestPair({
  String access = 'access_abc',
  String refresh = 'refresh_xyz',
  Duration lifetime = const Duration(hours: 1),
}) =>
    TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(lifetime),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterSecureStorage fakeSecure;
  late SecureTokenStorageImpl storage;

  setUp(() {
    fakeSecure = FakeFlutterSecureStorage();
    storage = SecureTokenStorageImpl.withStorage(fakeSecure);
    SharedPreferences.setMockInitialValues({});
  });

  // ── saveTokens ──────────────────────────────────────────────────────────────

  group('saveTokens', () {
    test('writes all three separate keys to secure storage', () async {
      final pair = _makeTestPair();
      await storage.saveTokens(pair);

      expect(fakeSecure._store['kayfit.access_token'], equals(pair.accessToken));
      expect(fakeSecure._store['kayfit.refresh_token'], equals(pair.refreshToken));
      expect(fakeSecure._store['kayfit.expires_at'], equals(pair.expiresAtIso));
    });

    test('overwrites existing keys when called again', () async {
      final first = _makeTestPair(access: 'first_access');
      final second = _makeTestPair(access: 'second_access');
      await storage.saveTokens(first);
      await storage.saveTokens(second);

      expect(fakeSecure._store['kayfit.access_token'], equals('second_access'));
    });
  });

  // ── loadTokens ──────────────────────────────────────────────────────────────

  group('loadTokens', () {
    test('returns null when storage is empty', () async {
      final result = await storage.loadTokens();
      expect(result, isNull);
    });

    test('returns null when legacy SharedPreferences is also empty', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await storage.loadTokens();
      expect(result, isNull);
    });

    test('returns TokenPair when all three keys are present', () async {
      final pair = _makeTestPair();
      await storage.saveTokens(pair);

      final loaded = await storage.loadTokens();

      expect(loaded, isNotNull);
      expect(loaded!.accessToken, equals(pair.accessToken));
      expect(loaded.refreshToken, equals(pair.refreshToken));
    });

    test('returns null (no crash) when PlatformException is thrown', () async {
      fakeSecure.throwOnRead = true;

      final result = await storage.loadTokens();

      expect(result, isNull);
    });

    test('migrates tokens from legacy SharedPreferences when SecureStorage empty',
        () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy_access',
        'refresh_token': 'legacy_refresh',
      });

      final result = await storage.loadTokens();

      expect(result, isNotNull);
      expect(result!.accessToken, equals('legacy_access'));
      expect(result.refreshToken, equals('legacy_refresh'));
    });

    test('removes legacy keys from SharedPreferences after migration', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy_access',
        'refresh_token': 'legacy_refresh',
      });

      await storage.loadTokens();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    test('saves migrated tokens into SecureStorage', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy_access',
        'refresh_token': 'legacy_refresh',
      });

      await storage.loadTokens();

      expect(fakeSecure._store['kayfit.access_token'], equals('legacy_access'));
      expect(fakeSecure._store['kayfit.refresh_token'], equals('legacy_refresh'));
    });

    test('migrated pair is expired (triggers immediate refresh on next start)',
        () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy_access',
        'refresh_token': 'legacy_refresh',
      });

      final result = await storage.loadTokens();

      expect(result, isNotNull);
      // expiresAt = DateTime.now() during migration; 60-second buffer makes
      // isExpired always true immediately.
      expect(result!.isExpired, isTrue);
    });
  });

  // ── loadAccessToken ─────────────────────────────────────────────────────────

  group('loadAccessToken', () {
    test('returns access token when pair was saved', () async {
      await storage.saveTokens(_makeTestPair(access: 'my_access'));
      expect(await storage.loadAccessToken(), equals('my_access'));
    });

    test('returns null when nothing is saved', () async {
      expect(await storage.loadAccessToken(), isNull);
    });

    test('returns null on PlatformException', () async {
      fakeSecure.throwOnRead = true;
      expect(await storage.loadAccessToken(), isNull);
    });
  });

  // ── loadRefreshToken ─────────────────────────────────────────────────────────

  group('loadRefreshToken', () {
    test('returns refresh token when pair was saved', () async {
      await storage.saveTokens(_makeTestPair(refresh: 'my_refresh'));
      expect(await storage.loadRefreshToken(), equals('my_refresh'));
    });

    test('returns null when nothing is saved', () async {
      expect(await storage.loadRefreshToken(), isNull);
    });
  });

  // ── clearTokens ──────────────────────────────────────────────────────────────

  group('clearTokens', () {
    test('deletes all three keys from secure storage', () async {
      await storage.saveTokens(_makeTestPair());

      await storage.clearTokens();

      expect(fakeSecure._store['kayfit.access_token'], isNull);
      expect(fakeSecure._store['kayfit.refresh_token'], isNull);
      expect(fakeSecure._store['kayfit.expires_at'], isNull);
    });

    test('is idempotent when storage is already empty', () async {
      await storage.clearTokens(); // must not throw
    });

    test('loadAccessToken returns null after clearTokens', () async {
      await storage.saveTokens(_makeTestPair());
      await storage.clearTokens();
      expect(await storage.loadAccessToken(), isNull);
    });
  });

  // ── H5: KeychainUnavailableException ─────────────────────────────────────────

  group('KeychainUnavailableException (H5)', () {
    test('loadTokens throws KeychainUnavailableException when code is -25308',
        () async {
      fakeSecure.throwKeychainUnavailable = true;

      expect(
        () => storage.loadTokens(),
        throwsA(isA<KeychainUnavailableException>()),
      );
    });

    test('loadTokens returns null for other PlatformException codes', () async {
      fakeSecure.throwOnRead = true;

      final result = await storage.loadTokens();

      expect(result, isNull);
    });

    test(
        'loadAccessToken throws KeychainUnavailableException when code is -25308',
        () async {
      fakeSecure.throwKeychainUnavailable = true;

      expect(
        () => storage.loadAccessToken(),
        throwsA(isA<KeychainUnavailableException>()),
      );
    });

    test(
        'loadRefreshToken throws KeychainUnavailableException when code is -25308',
        () async {
      fakeSecure.throwKeychainUnavailable = true;

      expect(
        () => storage.loadRefreshToken(),
        throwsA(isA<KeychainUnavailableException>()),
      );
    });
  });
}

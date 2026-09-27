// lib/core/auth/secure_token_storage.dart
//
// Secure persistence layer for JWT tokens.
// iOS  → Keychain (flutter_secure_storage default)
// Android → EncryptedSharedPreferences (API 23+)
//
// Migration: On first run after upgrade from a build that stored tokens in
// plain SharedPreferences (old TokenStorage), the tokens are moved here and
// deleted from SharedPreferences so they no longer live in plaintext.

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'token_pair.dart';

/// Thrown when iOS Keychain is temporarily unavailable — device has not been
/// unlocked after a reboot (OSStatus -25308, errSecInteractionNotAllowed).
/// This is NOT a sign that tokens are absent; it means the secure enclave
/// cannot be accessed until the user performs a first unlock.
class KeychainUnavailableException implements Exception {
  const KeychainUnavailableException(this.platformCode);
  final String platformCode;

  @override
  String toString() => 'KeychainUnavailableException(code: $platformCode)';
}

abstract interface class SecureTokenStorage {
  Future<void> saveTokens(TokenPair pair);
  Future<TokenPair?> loadTokens();
  Future<String?> loadAccessToken();
  Future<String?> loadRefreshToken();
  Future<void> clearTokens();
}

// ─── Storage keys ─────────────────────────────────────────────────────────────

const _kAccessToken = 'kayfit.access_token';
const _kRefreshToken = 'kayfit.refresh_token';
const _kExpiresAt = 'kayfit.expires_at';
const _kTokenPair = 'kayfit.token_pair.v2';

// Legacy SharedPreferences keys used before SecureTokenStorage was introduced.
// Only read during one-time migration; never written to.
const _kLegacyAccess = 'access_token';
const _kLegacyRefresh = 'refresh_token';

// ─── Implementation ────────────────────────────────────────────────────────────

class SecureTokenStorageImpl implements SecureTokenStorage {
  /// Default production constructor — uses platform Keychain / EncryptedPrefs.
  SecureTokenStorageImpl() : _storage = _buildStorage();

  /// Visible for testing: inject a custom [FlutterSecureStorage] instance.
  @visibleForTesting
  SecureTokenStorageImpl.withStorage(FlutterSecureStorage storage)
    : _storage = storage;

  // ignore: unused_element
  FlutterSecureStorage get storage => _storage;

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _buildStorage() => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<void> saveTokens(TokenPair pair) async {
    try {
      // One Keychain value is the commit point. A crash can no longer leave an
      // access token from one response paired with a refresh token from another.
      await _storage.write(
        key: _kTokenPair,
        value: jsonEncode(<String, String>{
          'access_token': pair.accessToken,
          'refresh_token': pair.refreshToken,
          'expires_at': pair.expiresAtIso,
        }),
      );
      // Remove the former multi-key representation only after the atomic value
      // is durable. Readers always prefer v2, so duplicates are never active.
      await Future.wait([
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kRefreshToken),
        _storage.delete(key: _kExpiresAt),
      ]);
    } on PlatformException catch (e) {
      // Never include token values in diagnostics. Callers must know the
      // atomic commit failed and must not publish an authenticated session.
      debugPrint('[SecureTokenStorage] saveTokens failed code=${e.code}');
      rethrow;
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Future<TokenPair?> loadTokens() async {
    // 1. Try SecureStorage first.
    try {
      final encoded = await _storage.read(key: _kTokenPair);
      if (encoded != null) {
        final value = jsonDecode(encoded) as Map<String, dynamic>;
        return TokenPair.fromStoredValues(
          accessToken: value['access_token'] as String,
          refreshToken: value['refresh_token'] as String,
          expiresAtIso: value['expires_at'] as String,
        );
      }

      // One-time migration from the previous three secure keys.
      final values = await Future.wait([
        _storage.read(key: _kAccessToken),
        _storage.read(key: _kRefreshToken),
        _storage.read(key: _kExpiresAt),
      ]);
      final access = values[0];
      final refresh = values[1];
      final expiresAt = values[2];

      if (access != null && refresh != null && expiresAt != null) {
        final pair = TokenPair.fromStoredValues(
          accessToken: access,
          refreshToken: refresh,
          expiresAtIso: expiresAt,
        );
        await saveTokens(pair);
        return pair;
      }
    } on PlatformException catch (e) {
      debugPrint('[SecureTokenStorage] loadTokens failed code=${e.code}');
      // errSecInteractionNotAllowed (-25308): Keychain locked after reboot.
      // This does NOT mean tokens are absent — rethrow so checkSession can
      // distinguish this case and avoid logging the user out.
      if (e.code == '-25308' || e.code == 'errSecInteractionNotAllowed') {
        throw KeychainUnavailableException(e.code);
      }
      return null;
    }

    // 2. Migration: check legacy SharedPreferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString(_kLegacyAccess);
      final legacyRefresh = prefs.getString(_kLegacyRefresh);

      if (legacyAccess != null && legacyRefresh != null) {
        debugPrint(
          '[SecureTokenStorage] Migrating tokens from SharedPreferences',
        );

        // expiresAt is unknown for legacy tokens → set to now so checkSession
        // will immediately attempt a refresh (which is the safe behaviour).
        final pair = TokenPair(
          accessToken: legacyAccess,
          refreshToken: legacyRefresh,
          expiresAt: DateTime.now(),
        );

        // Persist in SecureStorage and erase from SharedPreferences atomically.
        await saveTokens(pair);
        await Future.wait([
          prefs.remove(_kLegacyAccess),
          prefs.remove(_kLegacyRefresh),
        ]);

        return pair;
      }
    } catch (_) {
      debugPrint('[SecureTokenStorage] migration failed');
    }

    return null;
  }

  @override
  Future<String?> loadAccessToken() async {
    try {
      return (await loadTokens())?.accessToken;
    } on PlatformException catch (e) {
      debugPrint('[SecureTokenStorage] loadAccessToken failed code=${e.code}');
      if (e.code == '-25308' || e.code == 'errSecInteractionNotAllowed') {
        throw KeychainUnavailableException(e.code);
      }
      return null;
    }
  }

  @override
  Future<String?> loadRefreshToken() async {
    try {
      return (await loadTokens())?.refreshToken;
    } on PlatformException catch (e) {
      debugPrint('[SecureTokenStorage] loadRefreshToken failed code=${e.code}');
      if (e.code == '-25308' || e.code == 'errSecInteractionNotAllowed') {
        throw KeychainUnavailableException(e.code);
      }
      return null;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  @override
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _kTokenPair),
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kRefreshToken),
        _storage.delete(key: _kExpiresAt),
      ]);
    } on PlatformException catch (e) {
      debugPrint('[SecureTokenStorage] clearTokens failed code=${e.code}');
    }
  }
}

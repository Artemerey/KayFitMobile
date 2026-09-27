import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/api_client.dart';

class SignInCancelledException implements Exception {
  @override
  String toString() => 'SignInCancelledException';
}

class SocialAuthService {
  static const _appleServicesId = String.fromEnvironment(
    'APPLE_SERVICES_ID',
    defaultValue: 'com.kayfit.app.auth',
  );

  static const _appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://app.carbcounter.online/api/v1/auth/apple/callback',
  );

  static Future<Map<String, dynamic>> signInWithApple() async {
    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: _appleServicesId,
          redirectUri: Uri.parse(_appleRedirectUri),
        ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw SignInCancelledException();
      }
      rethrow;
    }

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw Exception('Apple did not return an identity_token');
    }

    final nameParts = [
      credential.givenName,
      credential.familyName,
    ].where((s) => s != null && s.isNotEmpty).toList();
    final name = nameParts.isEmpty ? null : nameParts.join(' ');

    final deviceId = await _getDeviceId();
    final resp = await apiDio.post(
      '/api/v1/auth/apple',
      data: {
        'identity_token': identityToken,
        'user_id': credential.userIdentifier ?? '',
        if (name != null) 'name': name,
        'device_id': deviceId,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<String> _getDeviceId() async {
    const key = 'cc_device_id';
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(key);
    if (id == null) {
      final rng = Random.secure();
      id = List.generate(
        16,
        (_) => rng.nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(key, id);
    }
    return id;
  }
}

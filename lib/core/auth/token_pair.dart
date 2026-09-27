// lib/core/auth/token_pair.dart
//
// Immutable value type representing an access + refresh token pair.
// Stored in SecureTokenStorage as three separate keys so the access token
// can be read without deserialising the full object.

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;

  /// Local expiry: computed at the moment the response is received.
  /// We subtract a 60-second buffer so refresh starts slightly early.
  final DateTime expiresAt;

  /// Whether the access token should already be considered expired.
  /// Uses a 60-second safety buffer to account for clock skew and RTT.
  bool get isExpired =>
      expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 60)));

  /// Construct from the raw API response map.
  /// `expires_in` is the token lifetime in seconds from the time of receipt.
  factory TokenPair.fromApiResponse(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int? ?? 3600;
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      // Subtract 60-second buffer so we refresh a little early.
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn - 60)),
    );
  }

  /// Construct from three individually stored string values.
  factory TokenPair.fromStoredValues({
    required String accessToken,
    required String refreshToken,
    required String expiresAtIso,
  }) => TokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.parse(expiresAtIso),
  );

  /// ISO-8601 representation for storage.
  String get expiresAtIso => expiresAt.toIso8601String();

  @override
  String toString() =>
      'TokenPair(expiresAt: $expiresAt, isExpired: $isExpired)';
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class FeedbackCapabilityStorage {
  Future<void> write(String targetId, String capability);
  Future<String?> read(String targetId);
  Future<void> delete(String targetId);
}

class SecureFeedbackCapabilityStorage implements FeedbackCapabilityStorage {
  SecureFeedbackCapabilityStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _prefix = 'kayfit.feedback_capability.';
  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String targetId, String capability) =>
      _storage.write(key: '$_prefix$targetId', value: capability);

  @override
  Future<String?> read(String targetId) =>
      _storage.read(key: '$_prefix$targetId');

  @override
  Future<void> delete(String targetId) =>
      _storage.delete(key: '$_prefix$targetId');
}

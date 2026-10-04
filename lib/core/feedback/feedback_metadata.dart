import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackMetadata {
  const FeedbackMetadata({
    required this.appVersion,
    required this.releaseVersion,
    required this.buildNumber,
    required this.platform,
  });

  final String appVersion;
  final String releaseVersion;
  final String buildNumber;
  final String platform;

  static FeedbackMetadata? current;

  static Future<void> initialize() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
    current = FeedbackMetadata(
      appVersion: version,
      releaseVersion: info.version,
      buildNumber: info.buildNumber.isEmpty ? '0' : info.buildNumber,
      platform: switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
        TargetPlatform.android || TargetPlatform.fuchsia => 'android',
        TargetPlatform.linux || TargetPlatform.windows => 'web',
      },
    );
  }
}

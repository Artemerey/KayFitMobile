import '../../../core/config/app_config.dart';

/// Resolves a slide's `image_url` to a fully-qualified URL.
///
/// Slide images are stored relative on the backend (e.g.
/// `/static/recipes/<slug>/01.jpg`) and served by the same nginx that fronts
/// the API. Absolute URLs (should the storage strategy change to S3/CDN) pass
/// through untouched.
String resolveRecipeImageUrl(String imageUrl) {
  final raw = imageUrl.trim();
  if (raw.isEmpty) return raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final path = raw.startsWith('/') ? raw : '/$raw';
  return '${AppConfig.baseUrl}$path';
}

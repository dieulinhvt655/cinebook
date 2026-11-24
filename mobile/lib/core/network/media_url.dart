import 'api_client.dart';

/// Image URLs from the API are either absolute (Cloudinary) or start with `/`: files bundled
/// with the backend, relative to the API base (`/media/posters/x.jpg`).
String? resolveMediaUrl(String? url, {String base = apiBaseUrl}) {
  if (url == null || url.isEmpty) return null;
  if (!url.startsWith('/')) return url;
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$b$url';
}

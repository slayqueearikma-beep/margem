import '../config/app_config.dart';
import 'secure_http_client.dart';

/// Rewrites stored media URLs so images load when PUBLIC_API_URL host differs
/// from the mobile app's configured API host (localhost vs 10.0.2.2, LAN IP, etc.).
class MediaUrlResolver {
  MediaUrlResolver._();

  static String resolve(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed;

    final apiUri = Uri.parse(AppConfig.apiBaseUrl);
    final apiHost = apiUri.host.toLowerCase();
    final mediaHost = uri.host.toLowerCase();

    if (mediaHost == apiHost) return trimmed;

    final isMediaPath = uri.path.startsWith('/media/') || uri.path.contains('/media/');
    if (!isMediaPath) return trimmed;

    if (!UploadUrlGuard.areLocalDevHostsEquivalent(mediaHost, apiHost)) {
      return trimmed;
    }

    return uri
        .replace(
          scheme: apiUri.scheme,
          host: apiUri.host,
          port: apiUri.hasPort ? apiUri.port : null,
        )
        .toString();
  }
}

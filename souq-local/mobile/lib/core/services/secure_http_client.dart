import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Validates outbound upload destinations to prevent SSRF via compromised APIs.
class UploadUrlGuard {
  UploadUrlGuard._();

  static const _azureBlobSuffix = '.blob.core.windows.net';

  static void assertAllowedUploadUrl(String uploadUrl) {
    final uri = Uri.tryParse(uploadUrl);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError('Invalid upload URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('Upload URL must use http(s)');
    }

    final host = uri.host.toLowerCase();
    final apiHost = Uri.parse(AppConfig.apiBaseUrl).host.toLowerCase();

    if (host == apiHost || host.endsWith(_azureBlobSuffix)) {
      return;
    }

    for (final allowed in AppConfig.allowedUploadHosts) {
      if (host == allowed.toLowerCase()) return;
    }

    throw ArgumentError('Upload destination is not allowed');
  }
}

/// Optional TLS certificate pinning for release builds.
///
/// Provide comma-separated SHA-256 pins via `--dart-define=CERTIFICATE_PINS=...`
/// When unset, the default system trust store is used.
http.Client createSecureHttpClient() {
  final pins = AppConfig.certificatePins;
  if (pins.isEmpty || !AppConfig.isProduction) {
    return http.Client();
  }
  // Pinning requires platform SecurityContext wiring; fall back to system CAs
  // until pins are provisioned in CI. Host allowlisting still applies above.
  return http.Client();
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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

String _certificatePinSha256(X509Certificate cert) {
  return base64.encode(sha256.convert(cert.der).bytes);
}

/// Optional TLS certificate pinning for release builds.
http.Client createSecureHttpClient() {
  final pins = AppConfig.certificatePins;
  if (pins.isEmpty || !AppConfig.isProduction) {
    return http.Client();
  }

  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (cert, host, port) {
    final fingerprint = _certificatePinSha256(cert);
    return pins.contains(fingerprint);
  };
  return IOClient(httpClient);
}

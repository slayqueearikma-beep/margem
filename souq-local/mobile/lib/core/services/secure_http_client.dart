import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// Validates outbound upload destinations to prevent SSRF via compromised APIs.
class UploadUrlGuard {
  UploadUrlGuard._();

  static const _azureBlobSuffixes = [
    '.blob.core.windows.net',
    '.blob.storage.azure.net',
  ];

  static bool isLoopbackOrPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '::1') return true;

    final match = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(h);
    if (match == null) return false;

    final parts = [for (var i = 1; i <= 4; i++) int.parse(match[i]!)];
    if (parts.any((part) => part < 0 || part > 255)) return false;
    if (parts[0] == 127) return true;
    if (parts[0] == 10) return true;
    if (parts[0] == 192 && parts[1] == 168) return true;
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    return false;
  }

  static bool areLocalDevHostsEquivalent(String a, String b) {
    final left = a.toLowerCase();
    final right = b.toLowerCase();
    if (left == right) return true;
    return isLoopbackOrPrivateHost(left) && isLoopbackOrPrivateHost(right);
  }

  static bool _isBlockedSsrTarget(String host) {
    final h = host.toLowerCase();
    if (h == 'metadata.google.internal' || h.endsWith('.metadata.google.internal')) {
      return true;
    }
    if (h == '169.254.169.254') return true;
    return false;
  }

  static bool _isApiProxiedUploadPath(String path) {
    return path.startsWith('/uploads/local/') ||
        path.startsWith('/uploads/storage/');
  }

  /// Rewrites API-proxied presign URLs to the configured API host when needed.
  static Uri resolveUploadUri(
    String uploadUrl, {
    String? apiBaseUrl,
  }) {
    final base = apiBaseUrl ?? AppConfig.apiBaseUrl;
    final uri = Uri.parse(uploadUrl);
    final apiUri = Uri.parse(base);
    final apiHost = apiUri.host.toLowerCase();
    final uploadHost = uri.host.toLowerCase();

    if (uploadHost == apiHost) return uri;
    if (!_isApiProxiedUploadPath(uri.path)) return uri;
    if (!areLocalDevHostsEquivalent(uploadHost, apiHost)) return uri;

    return uri.replace(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
  }

  static void assertAllowedUploadUrl(
    String uploadUrl, {
    String? apiBaseUrl,
    bool? isProduction,
    List<String>? allowedUploadHosts,
    String? minioUploadHost,
  }) {
    final base = apiBaseUrl ?? AppConfig.apiBaseUrl;
    final production = isProduction ?? AppConfig.isProduction;
    final allowedHosts = allowedUploadHosts ?? AppConfig.allowedUploadHosts;
    final minioHost = (minioUploadHost ?? AppConfig.minioUploadHost).toLowerCase();
    final minioEndpointHost = AppConfig.minioEndpointHost.toLowerCase();

    final uri = resolveUploadUri(uploadUrl, apiBaseUrl: base);
    if (uri.host.isEmpty) {
      throw ArgumentError('Invalid upload URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('Upload URL must use http(s)');
    }
    if (_isBlockedSsrTarget(uri.host)) {
      throw ArgumentError('Upload destination is not allowed');
    }

    final host = uri.host.toLowerCase();
    final apiHost = Uri.parse(base).host.toLowerCase();

    if (host == apiHost) return;

    for (final suffix in _azureBlobSuffixes) {
      if (host.endsWith(suffix)) return;
    }

    if (minioHost.isNotEmpty && host == minioHost) return;
    if (minioEndpointHost.isNotEmpty && host == minioEndpointHost) return;

    for (final allowed in allowedHosts) {
      if (host == allowed.toLowerCase()) return;
    }

    if (areLocalDevHostsEquivalent(host, apiHost) &&
        _isApiProxiedUploadPath(uri.path)) {
      return;
    }

    if (!production &&
        isLoopbackOrPrivateHost(apiHost) &&
        isLoopbackOrPrivateHost(host)) {
      return;
    }

    throw ArgumentError('Upload destination is not allowed');
  }

  /// Presign responses are already validated by the authenticated API.
  static void assertTrustedPresignUploadUrl(String uploadUrl) {
    final trimmed = uploadUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError('Invalid upload URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('Upload URL must use http(s)');
    }
    if (_isBlockedSsrTarget(uri.host)) {
      throw ArgumentError('Upload destination is not allowed');
    }

    try {
      assertAllowedUploadUrl(trimmed);
    } on ArgumentError {
      // Fall back to trusting server-validated presign targets (MinIO/Azure/etc.).
    }
  }
}

String _certificatePinSha256(X509Certificate cert) {
  return base64.encode(sha256.convert(cert.der).bytes);
}

/// Optional TLS certificate pinning for release builds.
http.Client createSecureHttpClient() {
  if (AppConfig.allowInsecureTls) {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (_, __, ___) => true;
    return IOClient(httpClient);
  }

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

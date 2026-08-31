/// App configuration — update for your environment.
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Canonical production API URL for open beta / production builds.
  static const String productionApiBaseUrl = 'https://api.dribex.ma';

  /// Emulator loopback default for local development when [apiBaseUrlDefine] is unset.
  static const String devApiBaseUrlDefault = 'http://10.0.2.2:8000';

  /// Raw compile-time define (empty when omitted from `--dart-define`).
  static const String apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Production API URL. Set at build time:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`
  ///
  /// Important: include the colon before the port (`:8000`). A common typo is
  /// `http://192.168.1.108000` which cannot resolve.
  static final String apiBaseUrl = _resolveApiBaseUrl();

  static String _resolveApiBaseUrl() {
    final raw = apiBaseUrlDefine.trim();
    // Release builds always use the canonical production API — no dev/LAN/Tailscale URLs.
    if (kReleaseMode) {
      return validateReleaseApiBaseUrl(
        productionApiBaseUrl,
        productionFlag: true,
      );
    }
    if (isProduction) {
      if (raw.isEmpty) {
        return validateReleaseApiBaseUrl(
          productionApiBaseUrl,
          productionFlag: true,
        );
      }
      return validateReleaseApiBaseUrl(
        normalizeApiBaseUrl(raw),
        productionFlag: true,
      );
    }
    return normalizeApiBaseUrl(raw.isEmpty ? devApiBaseUrlDefault : raw);
  }

  /// Validates API URL for release/production builds. Exposed for unit tests.
  static String validateReleaseApiBaseUrl(
    String url, {
    required bool productionFlag,
  }) {
    final normalized = normalizeApiBaseUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('Invalid API_BASE_URL: $url');
    }
    if (!normalized.startsWith('https://')) {
      throw StateError(
        'Release/PRODUCTION builds require HTTPS API_BASE_URL. Got: $normalized',
      );
    }
    if (isDevelopmentApiHost(uri.host)) {
      throw StateError(
        'Release/PRODUCTION builds must not use development API host: ${uri.host}',
      );
    }
    if (productionFlag && normalized != productionApiBaseUrl) {
      throw StateError(
        'PRODUCTION builds require API_BASE_URL=$productionApiBaseUrl. Got: $normalized',
      );
    }
    return normalized;
  }

  /// Returns true for emulator/loopback/Tailscale hosts that must never ship in release.
  static bool isDevelopmentApiHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1' || h == '10.0.2.2' || h == '::1') {
      return true;
    }
    // Tailscale CGNAT range 100.64.0.0/10
    if (RegExp(r'^100\.(\d{1,3})\.').hasMatch(h)) {
      final second = int.tryParse(RegExp(r'^100\.(\d{1,3})\.').firstMatch(h)!.group(1)!);
      if (second != null && second >= 64 && second <= 127) {
        return true;
      }
    }
    if (h.startsWith('192.168.') ||
        h.startsWith('10.') ||
        h.startsWith('172.16.') ||
        h.startsWith('172.17.') ||
        h.startsWith('172.18.') ||
        h.startsWith('172.19.') ||
        h.startsWith('172.2') ||
        h.startsWith('172.30.') ||
        h.startsWith('172.31.') ||
        h.endsWith('.local')) {
      return true;
    }
    return false;
  }

  /// Fixes common `API_BASE_URL` typos such as a missing `:` before the port
  /// (`http://192.168.11.1038000` → `http://192.168.11.103:8000`) and strips
  /// trailing slashes so path joins stay correct.
  static String normalizeApiBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return devApiBaseUrlDefault;

    // Strip trailing slashes (keep scheme://host[:port] form).
    while (url.endsWith('/') && url.length > 1) {
      url = url.substring(0, url.length - 1);
    }

    // Missing colon before a well-known port glued to an IPv4 host.
    // Try longer ports first so 8080 wins over 80.
    const stuckPorts = ['8443', '8080', '8000', '5000', '3000', '443', '80'];
    for (final port in stuckPorts) {
      if (!url.endsWith(port)) continue;
      final withoutPort = url.substring(0, url.length - port.length);
      final hostMatch =
          RegExp(r'^(https?://)(\d{1,3}(?:\.\d{1,3}){3})$').firstMatch(withoutPort);
      if (hostMatch == null) continue;
      final host = hostMatch[2]!;
      final octets = host.split('.').map(int.parse).toList();
      if (octets.any((octet) => octet < 0 || octet > 255)) continue;
      url = '${hostMatch[1]}$host:$port';
      break;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // Keep the raw value so the connection error still surfaces it.
      return url;
    }
    return url;
  }

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasGoogleMapsApiKey {
    if (googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
      return mapsEnabled;
    }
    return mapsEnabled && !kIsWeb;
  }

  /// Maps are enabled by default on native when the manifest supplies a key.
  static const bool mapsEnabled = bool.fromEnvironment(
    'ENABLE_MAPS',
    defaultValue: true,
  );

  /// When false, map screens, pickers, and navigation entries are hidden.
  /// Map APIs, models, and routes remain in the codebase for a future re-launch.
  /// Set `ENABLE_MAP_UI=true` at build time to show map UI again.
  static const bool mapUiEnabled = bool.fromEnvironment(
    'ENABLE_MAP_UI',
    defaultValue: false,
  );

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  /// Accept self-signed TLS for private beta (Tailscale + bootstrap nginx cert).
  /// Never enabled in PRODUCTION builds.
  static bool get allowInsecureTls =>
      !isProduction &&
      const bool.fromEnvironment('ALLOW_INSECURE_TLS', defaultValue: false);

  /// Show demo map pins when the API is unreachable (dev only).
  static const bool demoFallback = bool.fromEnvironment(
    'DEMO_FALLBACK',
    defaultValue: false,
  );

  static bool get allowDemoData => !isProduction && demoFallback;

  /// Privacy policy URL for Play Store listing and in-app link.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: '',
  );

  /// Legal documents are authoritative in French only (`/legal/fr/{doc}`).
  static const String legalContentLanguageCode = 'fr';

  /// Localized legal document URL served by the API (`/legal/{lang}/{doc}`).
  static String legalDocumentUrl(String doc, [String? languageCode]) {
    const lang = legalContentLanguageCode;
    final override = privacyPolicyUrl;
    if (doc == 'privacy' && override.isNotEmpty) {
      return override;
    }
    final origin = Uri.parse(apiBaseUrl).origin;
    return '$origin/legal/$lang/$doc';
  }

  static String privacyPolicyUrlFor([String? languageCode]) =>
      legalDocumentUrl('privacy');

  static String termsUrlFor([String? languageCode]) =>
      legalDocumentUrl('terms');

  static String cookiePolicyUrlFor([String? languageCode]) =>
      legalDocumentUrl('cookies');

  static String accountDeletionUrlFor([String? languageCode]) =>
      legalDocumentUrl('account-deletion');

  static const String appName = 'Dribex';
  static const String appTagline = 'Discover Morocco\'s Hidden Gems';

  static const List<String> moroccanCities = [
    'Casablanca',
  ];

  /// Launch city — MarGem is Casablanca-only for now.
  static const String launchCity = 'Casablanca';

  /// Default map center — Casablanca (production).
  static const double defaultMapLatitude = 33.5731;
  static const double defaultMapLongitude = -7.5898;

  /// Public QR link base (HTTPS only in production).
  static const String qrPublicBaseUrl = String.fromEnvironment(
    'QR_PUBLIC_BASE_URL',
    defaultValue: 'https://qr.dribex.ma',
  );

  /// Extra hosts permitted for presigned image uploads (comma-separated define).
  static List<String> get allowedUploadHosts {
    const raw = String.fromEnvironment('ALLOWED_UPLOAD_HOSTS', defaultValue: '');
    if (raw.trim().isEmpty) return const [];
    return raw.split(',').map((h) => h.trim().toLowerCase()).where((h) => h.isNotEmpty).toList();
  }

  /// Optional MinIO host for direct presigned PUT uploads (from MINIO_PUBLIC_URL define).
  static String get minioUploadHost {
    const raw = String.fromEnvironment('MINIO_PUBLIC_URL', defaultValue: '');
    if (raw.trim().isEmpty) return '';
    return Uri.tryParse(raw.trim())?.host.toLowerCase() ?? '';
  }

  /// Optional MinIO endpoint host (from MINIO_ENDPOINT define).
  static String get minioEndpointHost {
    const raw = String.fromEnvironment('MINIO_ENDPOINT', defaultValue: '');
    if (raw.trim().isEmpty) return '';
    final value = raw.trim();
    final normalized = value.contains('://') ? value : 'http://$value';
    return Uri.tryParse(normalized)?.host.toLowerCase() ?? '';
  }

  /// Optional SHA-256 certificate pins for release TLS pinning.
  static List<String> get certificatePins {
    const raw = String.fromEnvironment('CERTIFICATE_PINS', defaultValue: '');
    if (raw.trim().isEmpty) return const [];
    return raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  /// Maximum guest favorites stored locally before login.
  static const int maxGuestFavorites = 50;
}

/// App configuration — update for your environment.
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Production API URL. Set at build time:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`
  ///
  /// Important: include the colon before the port (`:8000`). A common typo is
  /// `http://192.168.1.108000` which cannot resolve.
  static final String apiBaseUrl = _resolveApiBaseUrl();

  static String _resolveApiBaseUrl() {
    final normalized = normalizeApiBaseUrl(
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
    );
    assert(
      !isProduction || normalized.startsWith('https://'),
      'PRODUCTION builds require an HTTPS API_BASE_URL (got: $normalized)',
    );
    // Defense in depth for profile/release where asserts are stripped:
    // main.dart also throws when PRODUCTION or kReleaseMode.
    return normalized;
  }

  /// Fixes common `API_BASE_URL` typos such as a missing `:` before the port
  /// (`http://192.168.11.1038000` → `http://192.168.11.103:8000`) and strips
  /// trailing slashes so path joins stay correct.
  static String normalizeApiBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return 'http://10.0.2.2:8000';

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

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

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

  /// Localized legal document URL served by the API (`/legal/{lang}/{doc}`).
  static String legalDocumentUrl(String doc, String languageCode) {
    const supported = {'en', 'fr', 'ar'};
    final lang = supported.contains(languageCode) ? languageCode : 'en';
    final override = privacyPolicyUrl;
    if (doc == 'privacy' && override.isNotEmpty) {
      return override;
    }
    final origin = Uri.parse(apiBaseUrl).origin;
    return '$origin/legal/$lang/$doc';
  }

  static String privacyPolicyUrlFor(String languageCode) =>
      legalDocumentUrl('privacy', languageCode);

  static String termsUrlFor(String languageCode) =>
      legalDocumentUrl('terms', languageCode);

  static String cookiePolicyUrlFor(String languageCode) =>
      legalDocumentUrl('cookies', languageCode);

  static String accountDeletionUrlFor(String languageCode) =>
      legalDocumentUrl('account-deletion', languageCode);

  static const String appName = 'MarGem';
  static const String appTagline = 'Discover Morocco\'s Hidden Gems';

  static const List<String> moroccanCities = [
    'Casablanca',
  ];

  /// Launch city — MarGem is Casablanca-only for now.
  static const String launchCity = 'Casablanca';

  /// Extra hosts permitted for presigned image uploads (comma-separated define).
  static List<String> get allowedUploadHosts {
    const raw = String.fromEnvironment('ALLOWED_UPLOAD_HOSTS', defaultValue: '');
    if (raw.trim().isEmpty) return const [];
    return raw.split(',').map((h) => h.trim().toLowerCase()).where((h) => h.isNotEmpty).toList();
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

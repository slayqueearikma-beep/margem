/// Helpers for TOTP MFA setup. Never log secrets or codes from these utilities.
class MfaUtils {
  MfaUtils._();

  static String? secretFromOtpAuthUri(String otpauthUri) {
    final uri = Uri.tryParse(otpauthUri.trim());
    if (uri == null) return null;
    final secret = uri.queryParameters['secret']?.trim();
    if (secret == null || secret.isEmpty) return null;
    return secret;
  }
}

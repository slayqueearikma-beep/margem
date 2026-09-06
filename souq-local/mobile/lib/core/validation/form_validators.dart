/// Shared client-side input validation (server remains authoritative).
class FormValidators {
  FormValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && _emailPattern.hasMatch(trimmed);
  }

  static bool isValidPassword(String value) {
    if (value.length < 8 || value.length > 128) return false;
    if (!RegExp(r'[A-Z]').hasMatch(value)) return false;
    if (!RegExp(r'[a-z]').hasMatch(value)) return false;
    if (!RegExp(r'\d').hasMatch(value)) return false;
    return true;
  }

  static String? emailError(String value) {
    if (value.trim().isEmpty) return 'required';
    if (!isValidEmail(value)) return 'invalid_email';
    return null;
  }

  static String? passwordError(String value) {
    if (value.isEmpty) return 'required';
    if (value.length < 8) return 'too_short';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'needs_uppercase';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'needs_lowercase';
    if (!RegExp(r'\d').hasMatch(value)) return 'needs_number';
    return null;
  }
}

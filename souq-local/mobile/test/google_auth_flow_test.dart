import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/auth/google_auth_flow.dart';
import 'package:souq_local/core/services/api_service.dart';
import 'package:souq_local/core/services/google_sign_in_helper.dart';
import 'package:souq_local/l10n/strings/app_strings_en.dart';

void main() {
  group('GoogleAuthFlow.normalizeRegistrationAccountType', () {
    test('accepts buyer aliases', () {
      expect(GoogleAuthFlow.normalizeRegistrationAccountType('buyer'), 'buyer');
      expect(GoogleAuthFlow.normalizeRegistrationAccountType('customer'), 'buyer');
    });

    test('accepts seller aliases', () {
      expect(GoogleAuthFlow.normalizeRegistrationAccountType('seller'), 'seller');
      expect(GoogleAuthFlow.normalizeRegistrationAccountType('provider'), 'seller');
    });

    test('rejects empty or unknown values', () {
      expect(GoogleAuthFlow.normalizeRegistrationAccountType(''), isNull);
      expect(GoogleAuthFlow.normalizeRegistrationAccountType('unknown'), isNull);
    });
  });

  group('GoogleAuthFlow.messageForError', () {
    const l10n = AppStringsEn();

    test('maps configuration errors to specific copy', () {
      expect(
        GoogleAuthFlow.messageForError(
          const GoogleSignInNotConfiguredException(),
          l10n,
        ),
        l10n.googleSignInNotConfigured,
      );
      expect(
        GoogleAuthFlow.messageForError(
          const GoogleSignInNoIdTokenException(),
          l10n,
        ),
        l10n.googleSignInNoIdToken,
      );
    });

    test('maps ApiException to its message', () {
      expect(
        GoogleAuthFlow.messageForError(
          ApiException('Cannot reach the server.'),
          l10n,
        ),
        'Cannot reach the server.',
      );
    });

    test('falls back to googleSignInFailed for unknown errors', () {
      expect(
        GoogleAuthFlow.messageForError(StateError('boom'), l10n),
        l10n.googleSignInFailed,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/auth_models.dart';

void main() {
  group('AuthUser legal acceptance parsing', () {
    test('defaults legalAcceptanceComplete to false when field is missing', () {
      final user = AuthUser.fromJson({
        'id': '00000000-0000-4000-8000-000000000001',
        'email': 'user@example.com',
        'account_type': 'customer',
        'display_name': 'User',
      });

      expect(user.legalAcceptanceComplete, isFalse);
      expect(user.pendingLegalPolicies, isEmpty);
    });

    test('parses explicit legal acceptance state from API', () {
      final user = AuthUser.fromJson({
        'id': '00000000-0000-4000-8000-000000000001',
        'email': 'user@example.com',
        'account_type': 'customer',
        'display_name': 'User',
        'legal_acceptance_complete': false,
        'pending_legal_policies': ['terms_of_service', 'privacy_policy'],
      });

      expect(user.legalAcceptanceComplete, isFalse);
      expect(user.pendingLegalPolicies, hasLength(2));
    });
  });

  group('GoogleSignInResult parsing', () {
    test('parses link_required response', () {
      final result = GoogleSignInResult.fromJson({
        'link_required': true,
        'email_hint': 'us***@example.com',
        'expires_in': 0,
      });

      expect(result.linkRequired, isTrue);
      expect(result.emailHint, 'us***@example.com');
      expect(result.session, isNull);
      expect(result.mfaRequired, isFalse);
    });

    test('parses mfa_required response', () {
      final result = GoogleSignInResult.fromJson({
        'mfa_required': true,
        'mfa_token': 'mfa-token-abc',
        'expires_in': 300,
      });

      expect(result.mfaRequired, isTrue);
      expect(result.mfaToken, 'mfa-token-abc');
      expect(result.session, isNull);
    });

    test('parses successful session response', () {
      final result = GoogleSignInResult.fromJson({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': '00000000-0000-4000-8000-000000000001',
          'email': 'google@example.com',
          'account_type': 'customer',
          'display_name': 'Google User',
          'email_verified': true,
        },
      });

      expect(result.linkRequired, isFalse);
      expect(result.session, isNotNull);
      expect(result.session!.accessToken, 'access');
      expect(result.session!.user.email, 'google@example.com');
    });
  });
}

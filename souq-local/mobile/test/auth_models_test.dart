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
}

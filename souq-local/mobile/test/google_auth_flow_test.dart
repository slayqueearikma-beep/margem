import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/auth/google_auth_flow.dart';

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
}

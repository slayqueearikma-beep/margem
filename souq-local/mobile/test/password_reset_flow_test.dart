import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/auth_route_guard.dart';
import 'package:souq_local/core/validation/form_validators.dart';

void main() {
  group('password reset route guard', () {
    test('forgot and reset routes are legal-exempt', () {
      expect(isLegalAcceptanceExemptLocation('/forgot-password'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/reset-password'), isTrue);
    });

    test('forgot and reset routes are not auth-protected', () {
      expect(isAuthProtectedLocation('/forgot-password'), isFalse);
      expect(isAuthProtectedLocation('/reset-password'), isFalse);
    });
  });

  group('password reset validation', () {
    test('accepts strong reset passwords', () {
      expect(FormValidators.isValidPassword('NewSecure1'), isTrue);
    });

    test('rejects weak reset passwords', () {
      expect(FormValidators.isValidPassword('password'), isFalse);
      expect(FormValidators.isValidPassword('short1A'), isFalse);
    });
  });
}

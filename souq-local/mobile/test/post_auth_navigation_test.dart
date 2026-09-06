import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/auth_route_guard.dart';

void main() {
  group('legal acceptance routing guard', () {
    test('blocks authenticated app surfaces including settings and search', () {
      expect(isLegalAcceptanceRequiredLocation('/buyer/home'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/search'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/settings'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/product/s1/p1'), isTrue);
    });

    test('allows auth onboarding and legal document routes', () {
      expect(isLegalAcceptanceExemptLocation('/login'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/onboarding/buyer-register'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/legal/accept'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/legal/terms'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/settings/privacy-legal'), isTrue);
    });
  });
}

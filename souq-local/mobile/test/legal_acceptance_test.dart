import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/auth_route_guard.dart';
import 'package:souq_local/features/legal/legal_acceptance_l10n.dart';

void main() {
  group('isLegalAcceptanceRequiredLocation', () {
    test('blocks main app routes until acceptance', () {
      expect(isLegalAcceptanceRequiredLocation('/buyer/home'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/seller/dashboard'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/profile'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/product/seller-1/product-1'), isTrue);
    });

    test('allows legal acceptance and policy routes', () {
      expect(isLegalAcceptanceExemptLocation('/legal/accept'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/legal/terms'), isTrue);
      expect(isLegalAcceptanceExemptLocation('/login'), isTrue);
      expect(isLegalAcceptanceRequiredLocation('/legal/accept'), isFalse);
    });
  });

  group('LegalAcceptanceCopy', () {
    test('uses Arabic UI with French legal acceptance for ar locale', () {
      final ar = LegalAcceptanceCopy.forLanguageCode('ar');
      expect(ar.title, 'قبل المتابعة');
      expect(ar.acceptanceLanguageCode, 'fr');
      expect(ar.legalContentNotice, isNotEmpty);
    });

    test('uses French for fr locale', () {
      final fr = LegalAcceptanceCopy.forLanguageCode('fr');
      expect(fr.title, 'Avant de continuer');
      expect(fr.acceptButton, 'J’accepte');
      expect(fr.acceptanceLanguageCode, 'fr');
    });

    test('uses English UI with French legal acceptance for en locale', () {
      final en = LegalAcceptanceCopy.forLanguageCode('en');
      expect(en.title, 'Before you continue');
      expect(en.acceptanceLanguageCode, 'fr');
      expect(en.legalContentNotice, isNotEmpty);
    });
  });
}

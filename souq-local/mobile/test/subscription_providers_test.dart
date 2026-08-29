import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/providers/subscription_providers.dart';

void main() {
  group('shouldShowPromotionalAds', () {
    test('shows ads when entitlements are null', () {
      expect(shouldShowPromotionalAds(null), isTrue);
    });

    test('shows ads when enabled and not suppressed', () {
      const enabled = EntitlementsBundleModel(
        buyer: BuyerEntitlementsModel(),
        adsEnabled: true,
      );
      expect(shouldShowPromotionalAds(enabled), isTrue);
    });

    test('hides ads when promotional ads are suppressed', () {
      const suppressed = EntitlementsBundleModel(
        buyer: BuyerEntitlementsModel(),
        adsEnabled: true,
        promotionalAdsSuppressed: true,
      );
      expect(shouldShowPromotionalAds(suppressed), isFalse);
    });

    test('hides ads when ads are disabled', () {
      const disabled = EntitlementsBundleModel(
        buyer: BuyerEntitlementsModel(),
        adsEnabled: false,
      );
      expect(shouldShowPromotionalAds(disabled), isFalse);
    });
  });
}

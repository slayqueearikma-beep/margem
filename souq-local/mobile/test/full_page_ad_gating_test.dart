import 'package:flutter_test/flutter_test.dart';

import 'package:souq_local/core/providers/subscription_providers.dart';
import 'package:souq_local/core/models/models.dart';

void main() {
  test('shouldShowPromotionalAds respects ads_enabled and suppression flags', () {
    expect(shouldShowPromotionalAds(null), isTrue);

    const enabled = EntitlementsBundleModel(
      buyer: BuyerEntitlementsModel(),
      adsEnabled: true,
      promotionalAdsSuppressed: false,
    );
    expect(shouldShowPromotionalAds(enabled), isTrue);

    const suppressed = EntitlementsBundleModel(
      buyer: BuyerEntitlementsModel(promotionalAdsSuppressed: true),
      adsEnabled: true,
      promotionalAdsSuppressed: true,
    );
    expect(shouldShowPromotionalAds(suppressed), isFalse);

    const disabled = EntitlementsBundleModel(
      buyer: BuyerEntitlementsModel(),
      adsEnabled: false,
    );
    expect(shouldShowPromotionalAds(disabled), isFalse);
  });
}

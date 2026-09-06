import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/models/service_pricing.dart';
import 'package:souq_local/l10n/strings/app_strings_en.dart';

void main() {
  final l10n = AppStringsEn();

  test('formatServicePrice renders fixed and range labels', () {
    expect(
      formatServicePrice(
        l10n,
        pricingModel: ServicePricingModel.fixedPrice,
        priceMad: 250,
      ),
      '250 MAD',
    );

    expect(
      formatServicePrice(
        l10n,
        pricingModel: ServicePricingModel.priceRange,
        priceMinMad: 100,
        priceMaxMad: 500,
      ),
      '100 MAD – 500 MAD',
    );

    expect(
      formatServicePrice(
        l10n,
        pricingModel: ServicePricingModel.requestQuote,
      ),
      'Request quote',
    );
  });
}
